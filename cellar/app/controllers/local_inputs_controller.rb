require_relative 'application_controller'
require 'will_paginate'
require 'will_paginate/active_record'
require 'sinatra/has_scope'
# require 'active_support/core_ext/time'
# require 'action_view'
require 'sinatra/cross_origin'

class LocalInputsController < ApplicationController
  register Sinatra::CrossOrigin
  # include ActionView::Helpers::DateHelper

  WillPaginate.per_page = 50

  register Sinatra::HasScope
  has_scope :local_input, :by_workflow_uuid

  before do
    response.headers["Access-Control-Allow-Origin"] = ENV['DAGGER_URL_PUBLIC']
    # pass if %w[auth login logout].include? request.path_info.split('/')[1]
    pass if request.options?
    verify_user
  end

  # :nocov:
  options "*" do
    response.headers["Allow"] = "POST, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Authorization, Cache-Control, X-Requested-With, Content-Type, Accept, X-User-Email, X-Auth-Token"
    # response.headers["Access-Control-Allow-Origin"] = "http://localhost:5000"
    200
  end

  get '/' do
    local_inputs = apply_scopes(:local_input, LocalInput, params).
        paginate(page: params[:page], per_page: params[:per_page])
    headers \
          "X-total"   => local_inputs.total_entries.to_s,
          "X-offset"  => local_inputs.offset.to_s,
          "X-limit"   => local_inputs.per_page.to_s

    json local_inputs
  end

  get '/:id/download' do
    li = LocalInput.find(params[:id])
    send_file(li.file.file.path,
              :filename => li.file.file.filename,
              :type => li.file.content_type,
              :disposition => 'attachment',
              :url_based_filename => true)
  end

  get '/:id' do
    json LocalInput.find(params[:id])
  end

  post '/' do
    json LocalInput.create!(allowed_params)
  end

  put '/:id' do
    json LocalInput.find(params[:id]).update!(allowed_params)
  end

  delete '/:id' do
    json LocalInput.find(params[:id]).destroy_all
  end

  private

  def allowed_params
    params.delete_if {|k,_| !['name', 'file', 'workflow_uuid', 'dest_path'].include?(k)}
  end

end