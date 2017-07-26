require 'dotenv/load'
require 'sinatra/base'
require 'sinatra/activerecord'
require 'sinatra-initializers'
require 'sinatra/reloader'
require 'sinatra/flash'
require 'sinatra/config_file'
require 'less'
require 'rack/healthcheck'
require 'sidekiq'
require 'sidekiq-statistic'

require_relative '../../lib/auth_extension'
require_relative '../../lib/application_helpers'
require_relative '../../lib/date_time_helpers'

class ApplicationController < Sinatra::Base
  root = File.expand_path('../../..', __FILE__)
  set :root, root
  Dir.glob("#{root}/app/workers/*.rb").each { |file| require file }

  # set :protection, :allow_if => lambda { |env|
  #   env['HTTP_REFERER'] =~ /^#{Regexp.escape('https://accounts.google.com/AccountChooser')}/
  # }

  register Sinatra::ActiveRecordExtension
  register Sinatra::Initializers
  register Sinatra::Flash
  register Sinatra::Auth
  # TODO: implement cusom error handlier

  helpers ApplicationHelpers
  helpers DateTimeHelpers

  # unless ENV['RACK_ENV'] == 'local' || ENV['RACK_ENV'] == 'development'
  #   set :show_exceptions, false
  # end

  # IMPORTANT
  # IMPORTANT
  # WARNING: environments has to be set before call to config_file
  register Sinatra::ConfigFile
  set :environments, %w{development test production local}
  config_file ['./config/*.erb']
  configure :test, :production, :development, :local do
    enable :logging
  end
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
    config.app_name = "Dagger"
    config.app_version = 1.0
    config.checks = [
        Rack::Healthcheck::Checks::ActiveRecord.new("dagger_#{ENV['RACK_ENV']}"),
        Rack::Healthcheck::Checks::Redis.new('redis', config = {
            url: settings.redis_url
        }),
        Rack::Healthcheck::Checks::HTTPRequest.new('users', config = {
            url: ENV['USERS_URL']+'/users',
            headers: {"Authorization" => "Token token=#{ENV['ADMIN_TOKEN']}"},
            service_type: "INTERNAL_SERVICE",
            expected_result: nil
        }),
        # Rack::Healthcheck::Checks::HTTPRequest.new('cellar', config = {
        #     url: ENV['CELLAR_URL']+'/results',
        #     headers: {"Authorization" => "Token token=#{ENV['ADMIN_TOKEN']}"},
        #     service_type: "INTERNAL_SERVICE",
        #     expected_result: nil
        # })
    ]
  end

  not_found do
    content_type :html
    halt [404, "No no no<br><img src='/images/no_no_cat.jpg'>"]
  end

  error ActiveRecord::RecordNotFound do
    halt 404, {
                 message: "Not found",
                 errors: [env['sinatra.error'].to_s]
              }.to_json
  end

  error ActiveRecord::RecordInvalid do
    halt 422, {
                 message: "Invalid record",
                 errors: [env['sinatra.error'].to_s]
               }.to_json
  end

  before do
    # dopass if %w[auth login logout css images js healthcheck].include? request.path_info.split('/')[1]
    # verify_logged_in_user
  end

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
    redirect to '/workflows/admin'
  end

  get '/login' do
    haml :login
  end



  get '/logout' do
    session.clear
    session[:return_to] = '/workflows/admin'
    redirect to '/login'
  end

end

