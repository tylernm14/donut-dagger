require_relative 'application_controller'
require 'will_paginate'
require 'will_paginate/active_record'
require 'sinatra/has_scope'

class JobEdgesController < ApplicationController
  WillPaginate.per_page = 50

  register Sinatra::HasScope

  has_scope :job_edge, :by_dependency_id
  has_scope :job_edge, :by_dependent_id
  has_scope :job, :by_workflow_uuid

  before  do
    verify_auth_token
  end

	get '/' do
    job_edge = apply_scopes(:job_edge, JobEdge, params).
        paginate(page: params[:page], per_page: params[:per_page])
    headers \
          "X-total"   => job_edge.total_entries.to_s,
          "X-offset"  => job_edge.offset.to_s,
          "X-limit"   => job_edge.per_page.to_s

    job_edge.to_json
  end

  post '/' do
    request.body.rewind
    request_payload = JSON.parse request.body.read
    JobEdge.create!(request_payload).to_json
  end

  get '/:id' do
    job_edge = JobEdge.find(params[:id])
    job_edge.to_json
  end

	put '/:id' do
    request.body.rewind
    request_payload = JSON.parse request.body.read
    job_edge = JobEdge.find(params[:id])
    job_edge.update!(request_payload)
    job_edge.to_json
  end


end

