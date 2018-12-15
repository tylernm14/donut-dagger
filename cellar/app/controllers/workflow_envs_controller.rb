require_relative 'application_controller'
require 'will_paginate'
require 'will_paginate/active_record'
require 'sinatra/has_scope'
# require 'active_support/core_ext/time'
# require 'action_view'

class WorkflowEnvsController < ApplicationController

  # include ActionView::Helpers::DateHelper

  WillPaginate.per_page = 50

  register Sinatra::HasScope
  has_scope :workflow_env, :by_workflow_uuid

  before do
    verify_user
  end

  get '/' do
    workflow_envs = apply_scopes(:workflow_env, WorkflowEnv, params).
        paginate(page: params[:page], per_page: params[:per_page])
    headers \
          "X-total"   => workflow_envs.total_entries.to_s,
          "X-offset"  => workflow_envs.offset.to_s,
          "X-limit"   => workflow_envs.per_page.to_s

    json workflow_envs
  end

  get '/:id/download' do
    we = WorkflowEnv.find(params[:id])
    fmt_time = Time.zone.at(DateTime.parse(we.created_at.to_s)).strftime("%Y-%m-%d_%H-%M-%S")
    send_file(we.zip_file.file.path,
              :filename => "we_snapshot_#{fmt_time}.zip",
              :type => 'application/zip',
              :disposition => 'attachment',
              :url_based_filename => true)
  end

  get '/:id' do
    json WorkflowEnv.find(params[:id])
  end

  post '/' do
    request.body.rewind
    request_payload = JSON.parse request.body.read
    json WorkflowEnv.create!(allowed_params(request_payload))
  end

  put '/:id' do
    json WorkflowEnv.find(params[:id]).update!(allowed_params)
  end

  delete '/:id' do
    json WorkflowEnv.find(params[:id]).destroy_all
  end

  private

  def allowed_params(h)
    h.slice('zip_file', 'workflow_uuid', 'status')
    # params.delete_if {|k,_| !['zip_file', 'workflow_uuid', 'status'].include?(k)}
  end

end