require 'json'
require 'restclient'
require 'timeout'

class DeleteKubeJobWorker
  include Sidekiq::Worker
  sidekiq_options queue: :delete_kube_job, retry: true, backtrace: true

  KUBE_API_ADDR = 'http://localhost:8001'

  def perform(job_id)
    @job = Job.find(job_id)
    delete_kube_job
  end

  private

  def delete_kube_job
    kube_job_name =  "#{@job.workflow.uuid}-#{@job.name}"
    begin
      Timeout::timeout(30) do
        response = RestClient.delete("#{KUBE_API_ADDR}/apis/batch/v1/namespaces/default/jobs/#{kube_job_name}")
        r_data = JSON.parse(response)
        if r_data['code'] != 200
          raise RuntimeError("Bad response for normal delete of job #{kube_job_name}. Got response: #{r_data.inspect}")
        end
      end
    rescue Timeout::Error => e
      response = RestClient.delete("#{KUBE_API_ADDR}/apis/batch/v1/namespaces/default/jobs/#{kube_job_name}", params: { gracePeriodSeconds: 0 })
      r_data = JSON.parse(response.body)
      if r_data['code'] != 200
        raise RuntimeError("Bad response for delete with gracePeriodSeconds=0 of job #{kube_job_name}. Got response: #{r_data.inspect}")
      end
    end
  end
end