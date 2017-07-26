require 'time'
require 'redis'


class JobDoneWorker
  include Sidekiq::Worker
  sidekiq_options queue: :job_done, retry: true, backtrace: true

  KUBE_API_ADDR = 'http://localhost:8001'

  def perform(job_id)
    @job = Job.find(job_id)
    @workflow = @job.workflow

    if @workflow.completed?
      $stderr.puts "ERROR: Job return after worklow completed.  Workflow completed with status: '#{@workflow.status}'"
      return
    end

    @ew =EtcdWorkflow.new(@workflow.uuid)
    @ew.with_lock do |w|
    # handle both job done/failure and timeout of other jobs in processing queue
    # we will need a watcher process to properly handle timeouts
      if @job.succeeded?
        w.update_job_status(@job.uuid, :succeeded)
        @job.dependents.each do |d|
          Job.increment_counter(:dependencies_succeeded_count, d.id)
          d.reload
          puts "Job '#{@job.name}' finished so incrementing dependencies_succeeded_count of dependent '#{d.name}'"
          if d.dependencies_succeeded_count == d.dependencies_count
            d.update!(status: :queued)
            w.set_job(EtcdWorkflow.job_repr(d, status: :queued))
          #if d.status == 'waiting'
            #w.set_job(EtcdWorkflow.job_repr(d, status: :queued))
            #d.update!(status: :queued)
          #else
            #w.set_job(EtcdWorkflow.job_repr(d))  # Not really needed
          end
        end
      else
        # cascade failure dependent_jobs
        # fail_workflow(w)
        fail_job(w)
        # TODO: KubeDelete of all launched remaining jobs
      end
      #Workflow.decrement_counter(:launched_jobs_count, workflow.id)
      DeleteKubeJobWorker.perform_async(@job.id)
      LaunchJobsWorker.perform_async(@workflow.id)
    end
  end

  private


  def fail_workflow(locked_etcd_workflow)
    puts "Job #{@job.uuid} with name '#{@job.name}' failed.  Failing workflow #{@workflow.uuid}"
    @job.failed!
    locked_etcd_workflow.update_job_status(@job.uuid, :failed )
    @workflow.failed!
    locked_etcd_workflow.set_status(:failed)
    #fail_jobs_recursively(@job)
  end

  def fail_job(locked_etcd_workflow)
    puts "Job #{@job.uuid} with name '#{@job.name}' was unsuccessful."
    @job.failed! if @job.running?
    locked_etcd_workflow.update_job_status(@job.uuid, :failed )
  end

  def fail_jobs_recursively(job)
    job.failed!
    job.dependents.each do |d|
      if not job.failed?
        fail_jobs_recursively(d)
      end
    end
  end


end

