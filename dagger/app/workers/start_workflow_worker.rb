require_relative '../../app/models/workflow'
require_relative '../../app/models/job'
require_relative '../../lib/etcd_utils'
require 'redis'
require 'timeout'
require 'aws-sdk'
require 'json'

class StartWorkflowWorker
  include Sidekiq::Worker
  sidekiq_options queue: :start_workflow, retry: true, backtrace: true

  def perform(workflow_id)
    puts "WORKFLOW ID: #{workflow_id}"
    @workflow = Workflow.find(workflow_id)
    @root_job = Job.find_by_uuid(@workflow.root_job_uuid)

    #create_workflow_storage

    @ew = EtcdWorkflow.new(@workflow.uuid)
    @ew.with_lock do |w|
      #w.enqueue(@workflow.uuid)
      @workflow.update!(status: :running)
      w.set_status(:running)
      @workflow.roots.each { |r| enqueue_job(w, r.job) }
      LaunchJobsWorker.perform_async(workflow_id)
    end
  end

  def enqueue_job(locked_workflow, job)
    create_etcd_jobs_recursively(locked_workflow, job)
    job_hash = EtcdWorkflow.job_repr(job, status: :queued)
    locked_workflow.set_job(job_hash)
    job.update!(status: :queued)
  end

  def create_etcd_jobs_recursively(ewl, job)
    ewl.set_job(EtcdWorkflow.job_repr(job))
    job.dependents.each do |d|
      if not ewl.job_exists?(d.uuid)
        create_etcd_jobs_recursively(ewl, d)
      end
    end
  end

end




