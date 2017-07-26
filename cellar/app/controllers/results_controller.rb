require_relative 'application_controller'
require 'will_paginate'
require 'will_paginate/active_record'
require 'sinatra/has_scope'

class ResultsController < ApplicationController
  WillPaginate.per_page = 50

  register Sinatra::HasScope
  has_scope :result, :by_job_id, :by_workflow_id #, :by_metadata, :search

  before do
    verify_user
  end

  get '/' do
    results = apply_scopes(:result, Result, params).
        paginate(page: params[:page], per_page: params[:per_page])
    headers \
          "X-total"   => results.total_entries.to_s,
          "X-offset"  => results.offset.to_s,
          "X-limit"   => results.per_page.to_s

    json results
  end


  get '/:id/download' do
    puts "Doing something"
    content_type :html
    result = Result.find(params[:id])
    puts result.file.inspect
    puts result.file.file.path
    puts result.file.file.content_type
    disposition = 'attachment'
    disposition = 'inline' if result.file.file.content_type.start_with? 'image'
    send_file(result.file.file.path,
              :filename => get_filename(result),
              :type => result.file.file.content_type,
              :disposition => disposition,
              :url_based_filename => true)
  end

  get '/:id/thumb' do
    content_type :html
    result = Result.find(params[:id])
    if result.file.file.content_type.start_with? 'image'
      image_type = result.file.file.content_type
      filepath = result.file.thumb.path
    else
      image_type = 'image/png'
      filepath = "#{settings.root}/#{settings.public_folder}#{result.file_url(:thumb)}"
    end
    puts filepath
    puts get_filename(result)
    puts image_type
    send_file(filepath,
              :filename => get_filename(result),
              :type => image_type,
              :disposition => 'inline',
              :url_based_filename => true)
  end

  get '/:id/large' do
    content_type :html
    result = Result.find(params[:id])
    if result.file.file.content_type.start_with? 'image'
      image_type = result.file.file.content_type
      filepath = result.file.large.path
    else
      image_type = 'image/png'
      filepath = "#{settings.root}/#{settings.public_folder}#{result.file_url(:large)}"
    end
    puts filepath
    puts get_filename(result)
    puts image_type
    send_file(filepath,
              :filename => get_filename(result),
              :type => image_type,
              :disposition => 'inline',
              :url_based_filename => true)# puts result.file.inspect
  end

  get '/:id' do
    json Result.find(params[:id])
  end

  post '/' do
    json Result.create!(allowed_params)
  end

  private

  def allowed_params
    params.delete_if {|k,_| !['file', 'name', 'workflow_id', 'job_id', 'job_name'].include?(k)}
  end

  def get_filename(result)
    if result.name
      filename = result.name
      if File.extname(filename) == ''
        filename << File.extname(result.file.file.filename)
      end
    else
      filename = result.file.file.filename
    end
    filename
  end

end