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
    propagation_data = {"kind": "DeleteOptions", "apiVersion": "batch/v1", "propagationPolicy": "Background"}
    kube_job_name =  "#{@job.workflow.uuid}-#{@job.name}"
    begin
      puts "Deleting job #{kube_job_name}"
      Timeout::timeout(30) do
        response = RestClient::Request.execute(method: :delete, url: "#{KUBE_API_ADDR}/apis/batch/v1/namespaces/default/jobs/#{kube_job_name}",
                                               payload: propagation_data.to_json, headers: { "Content-Type" => 'application/json'})
                                               # headers: { params: { propagationPolicy: 'Foreground'} } )
        r_data = JSON.parse(response.body)
        if response.code != 200
          raise RuntimeError.new("Bad response for normal delete of job #{kube_job_name}. Got response: #{response.inspect}")
        end
      end
    rescue Timeout::Error => e
      prop_and_grace_data = propagation_data.merge( { gracePeriodSeconds: 0} )
      response = RestClient::Request.execute(method: :delete, url: "#{KUBE_API_ADDR}/apis/batch/v1/namespaces/default/jobs/#{kube_job_name}",
                                             payload: prop_and_grace_data.to_json, headers: { "Content-Type" => 'application/json'})
      r_data = JSON.parse(response.body)
      if response.code != 200
        raise RuntimeError.new("Bad response for delete with gracePeriodSeconds=0 of job #{kube_job_name}. Got response: #{response.inspect}")
      end
    end
  end
end