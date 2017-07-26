require 'rubygems'
require 'bundler'
require 'dotenv/load'
require 'rack/rewrite'
require_relative 'app/controllers/application_controller'
require_relative 'app/controllers/users_controller'
require_relative 'app/controllers/tokens_controller'

ENV['RACK_ENV'] ||= 'development'
Bundler.require :default, ENV['RACK_ENV'].to_sym

# use Rack::Rewrite do
#   rewrite %r{^/\w{2}/users},  '/users'
#   rewrite %r{^/\w{2}/tokens}, '/tokens'
#   rewrite %r{^/\w{2}/},      '/'
# end
# # # pull in the helpers and controllers
# # Dir.glob('./app/{uploaders,services,models,helpers,controllers,workers}/*.rb').each { |file| require file }

# map the controllers to routes
map('/')                        { run ApplicationController }
map('/users')                 { run UsersController }
map('/tokens')                { run TokensController }
