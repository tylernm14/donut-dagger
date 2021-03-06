require 'active_resource'
require 'activeresource-response'

#This model is to represent the "snapshots" of the folder structure of a workflow on the NFS
class WorkflowEnv < ActiveResource::Base
  self.timeout = 10
  self.include_format_in_path = false
  self.site = ENV['CELLAR_URL']
  self.headers['Authorization'] = "Token token=#{ENV['ADMIN_TOKEN']}"
  add_response_method :http_response
end