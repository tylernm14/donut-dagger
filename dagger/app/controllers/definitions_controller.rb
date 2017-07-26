require_relative 'application_controller'
require 'will_paginate'
require 'will_paginate/active_record'
require 'sinatra/has_scope'

class DefinitionsController < ApplicationController
  WillPaginate.per_page = 50

  register Sinatra::HasScope
  has_scope :definition, :by_name

  before  do
    verify_auth_token
  end

  post '/' do
    Definition.create!(allowed_params).to_json
  end

  get '/' do
    definitions = apply_scopes(:definition, Definition, params).
        paginate(page: params[:page], per_page: params[:per_page])
    headers \
      "X-total"   => definitions.total_entries.to_s,
      "X-offset"  => definitions.offset.to_s,
      "X-limit"   => definitions.per_page.to_s

    definitions.to_json
  end

  get '/:id' do
    definition = Definition.find(params[:id])
    definition.to_json
  end

  put "/:id" do
    definition = Definition.find(params[:id])
    definition.update!(allowed_params)
    definition.to_json
  end

  delete '/:id' do
    Definition.delete(params[:id]).to_json
  end


  private

  def allowed_params
    request.body.rewind
    @request_payload = JSON.parse request.body.read
    @request_payload.slice('name','description','data')
  end




end