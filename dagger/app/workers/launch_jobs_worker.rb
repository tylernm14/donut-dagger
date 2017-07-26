require_relative '../../app/models/workflow'
require_relative '../../app/models/job'
require 'time'
require 'redis'
require 'rest-client'
require 'yaml'
require 'json'
require 'pp'

class UnschedulableJobError < StandardError
end


class LaunchJobsWorker
  include Sidekiq::Worker
  sidekiq_options queue: :launch_jobs, retry: true, backtrace: true

  WRAPPER_SCRIPT_CMD = 'run_streamed_job.py'
  CPU_ALLOCATED_PER_JOB = ENV['CPU_ALLOCATED_PER_JOB'] || '2'
  KUBE_API_ADDR = 'http://localhost:8001'
  # :nocov:
  SHARED_FS_MOUNT_PATH =  ENV['SHARED_FS_MOUNT_PATH'] || '/srv'
  SHARED_VOL_CLAIM = ENV['SHARED_VOL_CLAIM'] || begin
                                                   if ENV['RACK_ENV'] == 'local' || ENV['RACK_ENV'] == 'test'
                                                     'nfs-vol-claim'
                                                   elsif ENV['RACK_ENV'] == 'production'
                                                     'efs-vol-claim'
                                                   end
                                                 end
  # :nocov:

  def perform(workflow_id)
    puts max_job_nodes # if ENV['RACK_ENV'] != 'test'
    @workflow = Workflow.find(workflow_id)
    @etcd_workflow = EtcdWorkflow.new(@workflow.uuid)
    @etcd_workflow.with_lock do |w|
      if workflow_completed?(w)
        @workflow.update!(status: :done)
        w.set_status(:done)
        w.delete
        #w.dequeue
      else
        # Launch as many jobs as the cluster has room for assuming each job requires CPU_ALLOCATED_PER_JOB amount of cpu
        # check if we have room in the cluster for a job and find the first job in "queued" state
        # if first queued job cant be scheduled then we should pass until more resources free up
        #w.workflow_queue.each do |e|
        #ready_jobs = w.jobs(workflow: e).select { |uuid, job| ready_to_run?(job) }
        ready_jobs = w.jobs.select { |uuid, job| ready_to_run?(job) }
        puts "Found no jobs ready to run" if ready_jobs.size == 0
        puts "READY JOBS: "
        ready_keys = ready_jobs.keys
        [open_job_slots_count, ready_keys.size].min.times do |i|
          puts "readyjobs[readykeys][i]:#{ready_jobs[ready_keys[i]]} i: #{i}"
          begin
            launch(ready_jobs[ready_keys[i]])
            status = w.update_job_status(ready_jobs[ready_keys[i]]['uuid'], :running)
          rescue UnschedulableJobError => e
            $stderr.puts "ERROR: Can't schedule job #{ready_jobs[ready_keys[i]]['uuid']}"
            # need to pass on launching this job (maybe set to some other status like 'pending'?
          end
        end
        #end
      end
    end
  end

  private

  def max_job_nodes
    unless ENV['RACK_ENV'] == 'local'
      Aws.config.update({
      region: ENV['AWS_REGION'],
      credentials: Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY'])
      })
      s3 = Aws::S3::Client.new(region: 'us-east-1')
      resp = s3.get_object(bucket: ENV['KOPS_STATE_STORE'], key: "#{ENV['KOPS_JOBS_INSTANCE_GROUP_KEY']}")
      puts resp.body
      max_nodes = YAML.load(resp.body)['spec']['maxSize']
      puts "Found #{max_nodes} in kops instance group #{ENV['KOPS_JOBS_INSTANCE_GROUP_KEY']}"
      max_nodes
    else
      1
    end
  end

  def job_nodes(node_label = { 'cpu_usage' => 'red'})
    @job_nodes ||= begin
                     response = RestClient.get("#{KUBE_API_ADDR}/api/v1/nodes/", {accept: :json})
                     nodes = JSON.parse(response.body)
                     nodes.select {|n| n.dig('metadata', 'labels', node_label.keys().first) == node_label.values().first}
                   end
  end

  # Allocatable means available for scheduling
  def total_allocatable_job_nodes_cpu
    cpus = job_nodes.map {|n| n['status']['allocatable']['cpu'].to_i}
    cpus.inject {|sum,n| sum + n}
  end

  # Capacity is the total resources of a node
  def total_capacity_job_nodes_cpu
    cpus = job_nodes.map {|n| n['status']['capacity']['cpu'].to_i}
    cpus.inject {|sum,n| sum + n}
  end

  def total_allocatable_job_nodes_memory
    cpus = job_nodes.map {|n| n['status']['allocatable']['memory'].chomp('Ki').to_i}
    cpus.inject {|sum,n| sum + n}
  end

  def total_capacity_job_nodes_memory
    cpus = job_nodes.map {|n| n['status']['capacity']['memory'].chomp('Ki').to_i}
    cpus.inject {|sum,n| sum + n}
  end

  def workflow_completed?(ewl)
    ewl.jobs.size != ewl.jobs_by_status(:waiting).size &&
        ewl.jobs.size == ewl.jobs_by_status(:succeeded).size + ewl.jobs_by_status(:failed).size + ewl.jobs_by_status(:waiting).size +
        ewl.jobs_by_status(:terminated).size + ewl.jobs_by_status(:dead).size
  end

  def launch(job)
    puts "Job #{job.inspect}"
    puts "LAUNCHING #{job['uuid']}"
    job_rec = Job.find_by_uuid(job['uuid'])
    data = YAML.load(get_job_yml(job_rec))
    add_secret_env_vars(data)
    json_job = JSON.pretty_generate(data)
    puts "JSON JOB: #{json_job}"
    response = RestClient.post("#{KUBE_API_ADDR}/apis/batch/v1/namespaces/default/jobs",
                               json_job, {content_type: :json, accept: :json})
    jobname = data['metadata']['name']
    while not job_scheduled?(jobname)
      if job_unschedulable?(jobname)
        raise UnschedulableJobError("Pod wont fit need wait for launch until enough resources are available")
      else
        sleep 10
      end
    end
    orig_status = job_rec.status
    ActiveRecord::Base.transaction do
      job_rec.reload
      job_rec.update!(status: :launched) if job_rec.status == orig_status
    end
  end

  def job_scheduled?(jobname)
    pod = pod_of_job(jobname)
    response = RestClient.get("#{KUBE_API_ADDR}/api/v1/namespaces/default/pods/#{pod}")
    data = JSON.parse(response.body)
    scheduled_hash = data['status']['conditions'].select {|c| c['type'] == 'PodScheduled' }.first
    scheduled_hash['status'] == 'True'
  end

  def job_unschedulable?(jobname)
    pod = pod_of_job(jobname)
    response = RestClient.get("#{KUBE_API_ADDR}/api/v1/namespaces/default/pods/#{pod}")
    data = JSON.parse(response.body)
    scheduled_hash = data['status']['conditions'].select {|c| c['type'] == 'PodScheduled' }.first
    scheduled_hash['status'] == 'False' && scheduled_hash.dig('reason') == 'Unschedulable'
  end

  def pod_of_job(jobname)
    data = nil
    Timeout::timeout(20) do
      loop do
        sleep 2
        response = RestClient.get("#{KUBE_API_ADDR}/api/v1/namespaces/default/pods/?labelSelector=job-name%3D#{jobname}")
        data = JSON.parse(response.body)
        break if !!data['items'] && data['items'].size > 0
      end
    end
    data['items'][0]['metadata']['name']
  end

  def count_jobs(service_name)
    response = RestClient.get("#{KUBE_API_ADDR}/apis/batch/v1/namespaces/default/jobs?labelSelector=service-name=#{service_name}")
    data = JSON.parse(response.body)
    data['items'].nil? ? 0 : data['items'].size
  end

  def ready_to_run?(job)
    puts "Ready to run? Job:"
    pp job
    job['status'] == 'queued' # && dependencies_met?(job)
  end

  def dependencies_met?(job)
    job['dependencies_succeeded_count'] == job['dependencies_count']
  end

  def open_job_slots_count
    @workflow.parallelism - @etcd_workflow.jobs_by_status('running').count
  end

  def add_secret_env_vars(job_data)
    if ENV['DAGGER_JOB_SECRETS']
      secrets = JSON.parse(ENV['DAGGER_JOB_SECRETS'])
      secrets.each do |k,v|
        job_data['spec']['template']['spec']['containers'][0]['env'] << { 'name' => k,
                                                                          'value' => v }
      end
    end
  end

  def get_job_yml(job)
    job_yml =
    <<~HEREDOC
      ---
      apiVersion: batch/v1
      kind: Job
      metadata:
        name: #{job.workflow.uuid}-#{job.name}
      spec:
        activeDeadlineSeconds: 7200
        template:
          metadata:
            name: #{job.workflow.uuid}-#{job.name}
            labels:
              name: #{job.name}
              uuid: #{job.uuid}
          spec:
            containers:
            - name: #{job.name}
              image: "#{job.description['image']}"
              command:
              - "/usr/bin/env"
              args:
              - "--"
              - '#{WRAPPER_SCRIPT_CMD}'
              - '#{job.workflow.uuid}'
              - '#{job.to_json}'
              resources:
                requests:
                  cpu: #{CPU_ALLOCATED_PER_JOB}
                limits:
                  cpu: #{CPU_ALLOCATED_PER_JOB}
              env:
              - name: DAGGER_URL
                value: "http://dagger"
              - name: CELLAR_URL
                value: "http://cellar"
              - name: ADMIN_TOKEN
                value: #{ENV['ADMIN_TOKEN']}
              volumeMounts:
              - mountPath: '#{SHARED_FS_MOUNT_PATH}'
                name: shared-vol
            volumes:
            - name: shared-vol
              persistentVolumeClaim:
                claimName: '#{SHARED_VOL_CLAIM}'
            restartPolicy: Never
    HEREDOC
    puts "Launch job with spec: #{job_yml}"
    job_yml
  end

end
