ENV['RACK_ENV'] ||= 'test'
require 'rack/test'
require 'factory_girl'
require 'sidekiq/testing'
require 'simplecov'
require 'timecop'
require 'webmock/rspec'
require 'warden'
require 'dotenv/load'


SimpleCov.start do
  add_filter '/config\/initializers/'
  add_filter '/spec/'
end

SimpleCov.minimum_coverage 100
SimpleCov.root('.')

$:.unshift File.expand_path('../../app/controllers', __FILE__)
$:.unshift File.expand_path('../../app/models', __FILE__)
$:.unshift File.expand_path('../../app/workers', __FILE__)
$:.unshift File.expand_path('../../config', __FILE__)

Dir.glob('./app/{models,helpers,workers,services,controllers}/*.rb').each { |file| require file }
Dir.glob('./lib/{sinatra}/*.rb').each { |file| require file }
Dir.glob('./lib/health_monitor/providers/*.rb').each { |file| require file }

FactoryGirl.definition_file_paths = ['spec/factories']
FactoryGirl.find_definitions

def stub_user_token
  @user = { 'id' => 1,
            'name' => 'Tyler Martin',
            'login' => 'tylernm14',
            'oauth_id' => 123
  }
  @token = { 'value' => 'devtoken',
             'user' => @user,
             'id' => 1
  }
  stub_request(:get, "#{ENV['USERS_URL']}/tokens/#{ENV['ADMIN_TOKEN']}").
      with(headers: {'Accept'=>'application/json', 'Authorization'=>"Token token=#{ENV['ADMIN_TOKEN']}"}).
      to_return(status: 200, body: @token.to_json, headers: {})
  stub_request(:get, "#{ENV['USERS_URL']}/users/123").
      with(headers: {'Accept'=>'application/json', 'Authorization'=>"Token token=#{ENV['ADMIN_TOKEN']}"}).
      to_return(status: 200, body: @user.to_json, headers: {})
  [@user, @token]
end

def browser_sign_in
  user = { 'id' => 1,
           'name' => 'Tyler Martin',
           'login' => 'tylernm14',
           'avatar_url' => 'http://worldsawesomestcatpic.jpg',
           'oauth_id' => 123
  }
  user_attribs = { 'id' => 123,
                   'login' => 'tylernm14',
                   'name' => 'Tyler Martin',
                   'gravatar_id' => 123,
                   'avatar_url' => 'http://worldsawesomestcatpic.jpg',
                   'email' => 'tylernm@gmail.com',
                   'company' => nil,
                   'site_admin' => false
  }
  stub_request(:get, "#{ENV['USERS_URL']}/users/123").
      with(headers: {'Accept'=>'application/json', 'Authorization'=>"Token token=#{ENV['ADMIN_TOKEN']}"}).
      to_return(status: 200, body: user.to_json, headers: {})

  login_as Warden::GitHub::User.new(user_attribs)
end

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.include Warden::Test::Helpers
  config.include FactoryGirl::Syntax::Methods
  config.fail_fast = false
  config.before(:all) do
    Sidekiq::Testing.fake!
  end

  config.after(:each) { Warden.test_reset! }

  config.after(:all) do
    Sidekiq::Testing.fake!
    models = ActiveRecord::Base.subclasses - [ActiveRecord::SchemaMigration]
    models.map(&:destroy_all)
    FileUtils.rm_rf("tmp/uploads")
  end

  config.order = 'random'

  config.filter_run focus: true
  config.run_all_when_everything_filtered = true

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

end

require 'shoulda/matchers'

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec

    with.library :active_record
    with.library :active_model
  end
end
