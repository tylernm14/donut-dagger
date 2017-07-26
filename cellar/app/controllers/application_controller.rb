require 'dotenv/load'
require 'sinatra/base'
require 'sinatra/activerecord'
require 'sinatra-initializers'
require 'sinatra/reloader'
require 'sinatra/config_file'
require 'sinatra/i18n'
require 'rack/healthcheck'
require 'sidekiq'
require 'sidekiq-statistic'
require 'less'

require_relative '../../lib/auth_extension'

class ApplicationController < Sinatra::Base
  root = File.expand_path('../../..', __FILE__)
  Dir.glob("#{root}/app/workers/*.rb").each { |file| require file }
  set :root, root

  register Sinatra::ActiveRecordExtension
  register Sinatra::Initializers
  register Sinatra::I18n
  I18n.locale = :en
  register Sinatra::Auth

  # IMPORTANT
  # IMPORTANT
  # WARNING: environments has to be set before call to config_file
  register Sinatra::ConfigFile
  set :environments, %w{development test production local}
  config_file ['./config/*.erb']
  configure :test, :production, :development, :local do
    enable :logging
  end

  set :locales, "#{root}/config/locales/en.yml"
  set :public_folder, 'public'
  set :show_exceptions, false
  set :views, File.expand_path('../../views', __FILE__)

  Time.zone = 'Pacific Time (US & Canada)'

  # :nocov:
  ENV['REDIS_NAMESPACE_QUIET'] = 'true'
  # Sidekiq::Client.reliable_push! unless Sinatra::Base.test?
  Sidekiq.configure_client do |config|
    config.redis = {url: settings.redis_url, namespace: settings.redis_namespace }
  end

  Sidekiq.configure_server do |config|
    config.redis = {url: settings.redis_url, namespace: settings.redis_namespace }
    # config.timed_fetch! 10*60 # retry if job does not complete in 10 minutes
    # config.reliable_scheduler!
  end

  # :nocov:
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
  # :nocov:

  use Rack::Healthcheck::Middleware
  Rack::Healthcheck.configure do |config|
    config.app_name = "Cellar"
    config.app_version = 1.0
    config.checks = [
        Rack::Healthcheck::Checks::ActiveRecord.new("cellar_#{ENV['RACK_ENV']}"),
        Rack::Healthcheck::Checks::Redis.new('redis', config = {
            url: settings.redis_url
        }),
        Rack::Healthcheck::Checks::HTTPRequest.new('users', config = {
            url: ENV['USERS_URL']+'/users',
            headers: {"Authorization" => "Token token=#{ENV['ADMIN_TOKEN']}"},
            service_type: "INTERNAL_SERVICE",
            expected_result: nil
        })
    ]
  end

  not_found do
    content_type :html
    halt [404, "No no no<br><img src='/images/no_no_cat.jpg'>"]
  end

  error ActiveRecord::RecordNotFound do
    halt 404, json({
                       message: "Not found",
                       errors: [env['sinatra.error'].to_s]
                   })
  end

  # before do
  #   pass if %w[auth login logout].include? request.path_info.split('/')[1]
  #   verify_logged_in_user
  # end

  get '/css/application.css' do
    content_type :css
    less :"css/application"
  end

  get '/home' do
    verify_logged_in_user
    content_type :html
    haml :home
  end

  get '/' do
    verify_logged_in_user
    redirect to '/home'
  end

  # get '/login' do
  #   haml :login
  # end


  get '/logout' do
    session.clear
    session[:return_to] = '/home'
    redirect to '/home'
  end

end

