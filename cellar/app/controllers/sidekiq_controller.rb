require 'sidekiq/web'
require 'securerandom'

require_relative 'application_controller'

class SidekiqController < ApplicationController

  before do
    verify_logged_in_user
  end

  Sidekiq::Web.set :session_secret, ENV['SESSION_SECRET'] || SecureRandom.hex(64)

  [:get, :post, :put, :patch, :delete ].each do |method|
    __send__ method, '/*' do
      Sidekiq::Web.call(env)
    end
  end

end
