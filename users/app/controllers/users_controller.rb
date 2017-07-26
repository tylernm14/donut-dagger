require 'sinatra/has_scope'
require 'will_paginate'
require 'will_paginate/active_record'

require_relative 'application_controller'

class UsersController < ApplicationController
  WillPaginate.per_page = 50

  register Sinatra::HasScope

  before do
    verify_auth_token
  end

  get '/' do
    results = apply_scopes(:user, User, params).
        paginate(page: params[:page], per_page: params[:per_page])
    headers \
            "X-total"   => results.total_entries.to_s,
            "X-offset"  => results.offset.to_s,
            "X-limit"   => results.per_page.to_s
    results.to_json(include: { tokens: { only: :value } } )
  end

  get '/:oauth_id' do
    begin
      User.find_by!(oauth_id: params[:oauth_id]).to_json(include: { tokens: { only: :value } })
    rescue ActiveRecord::RecordNotFound
      halt 404, { 'message': "Couldn't find user" }.to_json
    end
  end

  post '/' do
    payload = allowed_params
    user = User.find_by(oauth_id: payload['oauth_id'])
    if user.nil?
      ActiveRecord::Base.transaction do
        user = User.create!(payload)
        Token.create!(user: user)
      end
    end
    user.to_json
  end

  def allowed_params
    request.body.rewind
    payload = JSON.parse request.body.read
    payload.slice('oauth_id', 'avatar_url', 'name', 'email', 'login')
  end

end