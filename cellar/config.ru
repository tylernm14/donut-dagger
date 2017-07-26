require 'dotenv/load'
require 'rubygems'
require 'bundler'
require 'sinatra/base'


ENV['RACK_ENV'] ||= 'development'
Bundler.require :default, ENV['RACK_ENV'].to_sym


# pull in the helpers and controllers
Dir.glob('./app/{uploaders,services,models,helpers,controllers,workers}/*.rb').each { |file| require file }

# map the controllers to routes
map('/')                        { run ApplicationController }
map('/results')                 { run ResultsController }
map('/workflow_envs')           { run WorkflowEnvsController }
map('/local_inputs')            { run LocalInputsController }
map('/sidekiq/cellar')                 { run SidekiqController }
