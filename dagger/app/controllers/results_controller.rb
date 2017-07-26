require 'active_record'
require_relative 'application_controller'
require 'will_paginate'
require 'will_paginate/active_record'
require 'will_paginate/view_helpers/sinatra'


class ResultsController < ApplicationController

  helpers WillPaginate::Sinatra::Helpers
  WillPaginate.per_page = 50
  register Sinatra::Namespace

  namespace '/admin' do
    before do
      verify_logged_in_user
      content_type 'text/html'
    end

    get do
      if result_params.key?('by_workflow_id')
        query_type = 'workflow'
        title = Workflow.find(params[:by_workflow_id]).definition.description
      #   result_filter = Proc.new { Result.where(by_workflow_id: result_params['by_workflow_id']) }
      elsif result_params.key?('by_job_id')
        query_type = 'job'
        title = Job.find(params[:by_job_id]).name
      #   result_filter = Proc.new { Result.where(by_job_id: result_params['by_job_id']) }
      else
        query_type = :unknown
        title = ''
      #   result_filter =  Proc.new { Result.all }
      end
      query_params = {page: params[:page] || 1, per_page: params[:per_page] || 60}
      query_params.update(result_params)
      results = Result.all(params: query_params)
      @xtotal = results.http_response['X-total'].to_i
      @results = WillPaginate::Collection.create(query_params[:page], query_params[:per_page], @xtotal) do |pager|
        pager.replace results
      end
      @total = @results.total_entries
      haml :'admin/results/index', locals: {results: @results, xtotal: @xtotal, total: @total, query_type: query_type, title: title}
    end

    get '/:id' do
      begin
        @result = Result.find(params[:id])
      rescue ActiveResource::Exception => e
        @result = nil
        flash[:error] = "ActiveResource 'Result' raised error #{e.message}"
      end
      @workflow = Workflow.find(@result.workflow_id)
      @job = Job.find(@result.job_id)
      haml :'admin/results/show', locals: {result: @result, workflow: @workflow, job: @job}
    end

  end


  def result_params
    params.slice(:page, :per_page, :by_workflow_id, :by_job_id)
  end

end
