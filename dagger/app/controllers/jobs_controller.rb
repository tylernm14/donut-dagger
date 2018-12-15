require_relative 'application_controller'
require 'will_paginate'
require 'will_paginate/active_record'
require 'sinatra/has_scope'
require 'sinatra/namespace'

class JobsController < ApplicationController
  WillPaginate.per_page = 50
  register Sinatra::Namespace
  register Sinatra::HasScope

  has_scope :job, :by_status
  has_scope :job, :by_uuid
  has_scope :job, :by_workflow_uuid

  deps_assoc_options = { include: { dependencies: { only: :uuid }, dependents: { only: :uuid}} }

  before do
    verify_user
  end

  namespace '/admin' do
    before do
      content_type 'text/html'
    end

    get '/:id' do
      @job = Job.find(params[:id])
      haml :'admin/jobs/show', locals: { job: @job}
    end
  end

  # oddly can't group top level actions into namespace '/' so they are defined individually below
  post '/' do
    request.body.rewind
    request_payload = JSON.parse request.body.read
    workflow = Workflow.find_by_uuid!(request_payload.fetch('workflow_uuid'))
    request_payload.except!('workflow_uuid')
    dependencies = []
    dependents = []
    dependencies = request_payload['dependencies'].map { |p| Job.find_by_uuid p['uuid']} if request_payload.key?('dependencies')
    dependents = request_payload['dependents'].map { |p| Job.find_by_uuid p['uuid']} if request_payload.key?('dependents')
    request_payload.delete('dependencies')
    request_payload.delete('dependents')
    job = nil
    ActiveRecord::Base.transaction do
      job = Job.create!(request_payload)
      dependencies.each {|d| JobEdge.create!(workflow: workflow, dependency: d, dependent: job)}
      dependents.each {|d| JobEdge.create!(workflow: workflow, dependency: job, dependent: d)}
      job.reload
    end
    job.to_json( include: { dependencies: { only: :uuid }, dependents: { only: :uuid}})
  end

  put '/:id' do
    #
    # NOTE: doesn't support update of job edges (ie. depenednts and dependencies)
    #
    request.body.rewind
    request_payload = JSON.parse request.body.read
    job = Job.find(params[:id])
    job.update!(request_payload)
    job.to_json(deps_assoc_options)
  end

  get '/' do
    jobs = apply_scopes(:job, Job, params).
        paginate(page: params[:page], per_page: params[:per_page])
    headers \
          "X-total"   => jobs.total_entries.to_s,
          "X-offset"  => jobs.offset.to_s,
          "X-limit"   => jobs.per_page.to_s
    jobs.to_json(deps_assoc_options)
  end

  get '/:id' do
    Job.find(params[:id])
        .to_json( include: [{ workflow: { except: [:description] }}, { dependencies: { only: :uuid }}, { dependents: { only: :uuid}}] )
  end

end
