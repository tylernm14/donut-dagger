require_relative 'application_controller'
require 'will_paginate'
require 'will_paginate/active_record'
require 'sinatra/has_scope'
require 'sinatra/namespace'
require 'rest-client'

class WorkflowEnvsController < ApplicationController
  before do
    verify_auth_token
  end

  post '/' do
    request_payload = JSON.parse request.body.read
    headers = { Authorization: "Token token=#{ENV['ADMIN_TOKEN']}", content_type: 'application/x-www-form-urlencoded'}
    r = RestClient.post("#{ENV['CELLAR_URL']}/workflow_envs?workflow_uuid=#{request_payload['workflow_uuid']}", {},  headers)
    r.body
  end

end
