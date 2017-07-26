require 'rubygems'
require 'bundler'
require 'sinatra/base'
require 'dotenv/load'

ENV['RACK_ENV'] ||= 'development'
Bundler.require :default, ENV['RACK_ENV'].to_sym

# pull in the helpers and controllers
Dir.glob('./app/{uploaders,services,models,helpers,controllers,workers}/*.rb').each { |file| require file }

# map the controllers to routes

map('/')                        { run ApplicationController }
map('/workflows')               { run WorkflowsController }
map('/definitions')               { run DefinitionsController }
map('/jobs')                    { run JobsController }
map('/job_edges')               { run JobEdgesController }
map('/results')                 { run ResultsController }
map('/workflow_envs')           { run WorkflowEnvsController }
map('/sidekiq/dagger')                 { run SidekiqController }
