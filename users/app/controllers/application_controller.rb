require 'dotenv/load'
require 'sinatra/base'
require 'sinatra/activerecord'
require 'sinatra/reloader'
require 'sinatra_auth_github'
require 'securerandom'
require 'rack/healthcheck'
# require 'rack/token_auth'

require_relative '../models/user'


class ApplicationController < Sinatra::Base

  include Warden::GitHub::SSO

  set :root, File.expand_path('../../..', '__FILE__')

  set :github_options, {
      :scopes    => "user",
      :secret    => ENV['GITHUB_CLIENT_SECRET'],
      :client_id => ENV['GITHUB_CLIENT_ID'],
  }

  # enable :sessions
  set :sessions, domain: ".#{ENV['DOMAIN']}"
  set :session_secret, ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }
  # ENV['WARDEN_GITHUB_VERIFIER_SECRET'] ||= SecureRandom.hex(64)
  register Sinatra::Auth::Github

  set :environments, %w{development test production local}
  configure :test, :production, :development, :local do
    enable :logging
  end

  configure(:development) do
    register Sinatra::Reloader
    also_reload "#{root}/app/models/*.rb"
    also_reload "#{root}/app/controllers/*.rb"
    also_reload "#{root}/app/views/**/*.rb"
    also_reload "#{root}/app/workers/*.rb"
    also_reload "#{root}/app/services/*.rb"
    also_reload "#{root}/app/uploaders/*.rb"
    also_reload "#{root}/lib/*.rb"
  end

  use Rack::Healthcheck::Middleware
  Rack::Healthcheck.configure do |config|
    config.app_name = "Users"
    config.app_version = 1.0
    config.checks = [
        Rack::Healthcheck::Checks::ActiveRecord.new("users_#{ENV['RACK_ENV']}")
    ]
  end

  before do
    # puts "SESSION INSPECT #{session.inspect}"
    if %w[auth login logout healthcheck].include? request.path_info.split('/')[1]
      pass
    else
      # verify_auth_token
      # verify_logged_in_user
    end
  end


  get '/login' do
    # return_to = session['return_to']
    # session['orig_return_to'] = back
    @return_to_url = session['orig_return_to']
    puts "Would return to #{session['orig_return_to']}"
    puts session.inspect
    if authenticated?
      @current_user = User.from_oauth(github_user)
      puts "Setting user id to #{@current_user.id}"
      session[:user_id] = @current_user.id
      session[:my_return_to] = @return_to_url
      puts "Session after setting user_id #{session.inspect}"
      puts "OMG"
    else
      verify_logged_in_user
    end
    # session.delete('orig_return_to')
    # redirect @return_to_url
  end

  get '/stuff' do
    puts github_user.inspect
    verify_logged_in_user
    puts session.inspect
    "Hellooooo, #{github_user.login} <a href='/login'>Login</a>"
  end

  get '/home' do
    if session['orig_return_to']
      redirect session['orig_return_to']
    end
    "Home :-) <a href='/login'>Login</a>"
  end

  get '/logout' do
    logout!
    session.clear
    redirect '/home'
  end

  get '/' do
    if session['orig_return_to']
      redirect['orig_return_to']
    else
      redirect '/home'
    end
  end


  private

  # To be used by services
  def verify_auth_token
    halt 401 unless valid_user?(extracted_token)
  end

  def valid_user?(token)
    t = Token.find_by_value(token)
    if t
      @current_user = t.user
    else
      @current_user = nil
    end
  end

  def extracted_token
    pattern = /Token\s*token=(.*)/
    c = pattern.match(env['HTTP_AUTHORIZATION'])
    if c && c.captures.size
      c.captures[0]
    else
      nil
    end
  end

  # to be used by webpage viewers
  def verify_logged_in_user
    unless github_user && warden_github_sso_session_valid?(github_user, 120)
      request.env['warden'].logout
      request.env['warden'].authenticate!
    end
    @current_user = User.from_oauth(github_user)
    puts "Setting user id to #{@current_user.id}"
    session[:user_id] = @current_user.id
    session[:my_return_to] = @return_to_url
    puts "Session after setting user_id #{session.inspect}"
    puts "OMG"
  end

end