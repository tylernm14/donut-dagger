require_relative 'application_controller'
require 'will_paginate'
require 'will_paginate/active_record'
require 'sinatra/has_scope'
require_relative '../services/../services/find_or_create_definition'
require 'sinatra/namespace'
require 'active_support/core_ext/time'
require 'activeresource'
require 'rack/protection'

class WorkflowsController < ApplicationController

  use Rack::Protection::FormToken

  WillPaginate.per_page = 50
  register Sinatra::Namespace
  register Sinatra::HasScope
  has_scope :workflow, :by_status
  has_scope :workflow, :by_uuid
  has_scope :workflow, :by_user_oauth_id

  namespace '/admin' do
    before do
      verify_logged_in_user
      content_type 'text/html'
    end

    get do
      @workflows = Workflow.all
      haml :'admin/workflows/index', locals: { workflows: @workflows, user_token: @current_user.tokens.first.value }
    end

    post do
      request_payload = allowed_params(params)
      puts request_payload.inspect
      workflow = post_common(request_payload)
      redirect to "/admin/#{workflow.id}"
    end


    get '/new/:id' do
      w = Workflow.find(params[:id])
      @new_uuid = SecureRandom.uuid
      yaml_def_data = w.definition.data.to_yaml
      haml :'admin/workflows/new', locals: { input_description: w.definition.description, placeholder_description: '',
                                             input_data: yaml_def_data, placeholder_data: nil,
                                             input_parallelism: w.parallelism, placeholder_parallelism: '',
                                             new_uuid: @new_uuid
                                           }
    end

    get '/new' do
      @new_uuid = SecureRandom.uuid
      haml :'admin/workflows/new', locals: { input_description: '', placeholder_description: 'Your friendly description here',
                                             input_data: nil, placeholder_data: "Workflow definition...\nSee /examples/sim_render.yaml or /examples/fruitbox_gather.yaml",
                                             input_parallelism: '', placeholder_parallelism: 1,
                                             new_uuid: @new_uuid,
                                             csrf_token: Rack::Protection::FormToken.token(session)
                                           }
    end

    get '/:id' do
      @workflow = Workflow.find(params[:id])
      @job_edges = JobEdge.where(workflow_id: @workflow.id).map {|e| [Job.find(e.dependency_id).name, Job.find(e.dependent_id).name]}
      begin
        @workflow_envs = WorkflowEnv.find(:all, params: { by_workflow_uuid: @workflow.uuid} )
      rescue StandardError => e
        @workflow_envs = []
        flash[:error] = "ActiveResource 'WorkflowEnv' raised error #{e.message}"
      end
      jobs_json = @workflow.jobs.to_json(except: [:stdout, :stderr, :messages])
      haml :'admin/workflows/show', locals: { workflow: @workflow, workflow_envs: @workflow_envs,
                                              jobs_json: jobs_json, job_edges_json: @job_edges.to_json,
                                              user_token: @current_user.tokens.first.value }
    end

  end


  namespace '/' do
    before do
      verify_user
    end

    post do
      request.body.rewind
      request_payload = JSON.parse request.body.read
      puts request_payload
      post_common(request_payload).to_json
    end

    get do
      workflows = apply_scopes(:workflow, Workflow, params).
          paginate(page: params[:page], per_page: params[:per_page])
      headers \
            "X-total" => workflows.total_entries.to_s,
            "X-offset" => workflows.offset.to_s, "X-limit" => workflows.per_page.to_s

      workflows.to_json(methods: custom_methods, include: custom_includes  )
    end

    get ':id' do
      wrkfl = Workflow.find(params[:id])
      wrkfl.to_json(methods: custom_methods, include: custom_includes)
    end

    put ':id' do
      request.body.rewind
      request_payload = JSON.parse request.body.read
      workflow = Workflow.find(params[:id])
      workflow.update!(status: request_payload.fetch('status'))
      json workflow
    end
  end


  private

  def custom_includes
    [ :definition, :jobs, :roots ]
  end

  def custom_methods
    incl_methods = []
    incl_methods += Job.statuses.map { |s| "jobs_#{s.first}_count" }
    incl_methods += [:jobs_total_count, :owner, :root_names]
    incl_methods
  end

  def allowed_params(create_hash)
    create_hash.slice('description', 'parallelism', 'data')
  end

  def post_common(request_payload)
    create_params = { 'uuid' => request_payload['uuid']}
    begin
      definition = FindOrCreateDefinition.call(request_payload)
    rescue InvalidDefinitionError => e
      halt 422, json({ message: 'Invalid Definition', errors: e.message })
    end

    create_params['definition_id'] = definition.id
    create_params['user_oauth_id'] = @current_user.oauth_id
    create_params['parallelism'] = request_payload['parallelism'] || definition.data['parallelism'] || 1
    Workflow.create!(create_params)
  end

end
