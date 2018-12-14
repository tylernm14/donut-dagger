require 'sinatra/has_scope'
require 'will_paginate'
require 'will_paginate/active_record'

require_relative 'application_controller'


class TokensController < ApplicationController

  register Sinatra::HasScope
  has_scope :token, :by_value
  has_scope :token, :by_user_id

  WillPaginate.per_page = 50

  before do
    verify_user
  end

  get '/' do
    results = apply_scopes(:token, Token, params).
        paginate(page: params[:page], per_page: params[:per_page])
    headers \
            "X-total"   => results.total_entries.to_s,
            "X-offset"  => results.offset.to_s,
            "X-limit"   => results.per_page.to_s
    results.to_json(include: :user)
  end

  get '/:value' do
    begin
      Token.find_by!(value: params[:value]).to_json(include: :user)
    rescue ActiveRecord::RecordNotFound
      halt 404, { 'message': "Couldn't find token" }.to_json
    end
  end



end
