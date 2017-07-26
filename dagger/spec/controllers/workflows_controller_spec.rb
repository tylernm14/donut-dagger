require 'spec_helper'
require 'pp'

describe WorkflowsController, :type => :controller do
  let(:app) { WorkflowsController }
  let(:browser) { Rack::Test::Session.new(Rack::MockSession.new(WorkflowsController, 'myapp.dev')) }

  before do
    Definition.destroy_all
    allow(StartWorkflowWorker).to receive(:perform_async).with(any_args)
    #allow(CreateDagJobs).to receive(:call).with(any_args)
    stub_user_token
  end

  describe 'GET /' do
    before do
      Workflow.destroy_all
      Job.delete_all
      @w1 = create(:workflow, user_oauth_id: @user['oauth_id'])
      @w1.update(status: :running)
      @w2 = create(:workflow, status: :queued, user_oauth_id: @user['oauth_id'])
      browser.get '/', {}, {'Content-Type' => 'application/json', 'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
      @workflows = JSON.parse(browser.last_response.body)
    end

    it 'is successful' do
      expect(browser.last_response.status).to eq 200
    end

    it 'returns workflows' do
      expect(@workflows.count).to eq(2)
      expect(@workflows[1]['uuid']).to eq(@w1.uuid)
      expect(@workflows[0]['uuid']).to eq(@w2.uuid)
    end

    it 'returns definitions' do
      expect(@workflows[0]['definition']['name']).to eq @w2.definition.name
    end

    it 'returns owner' do
      expect(@workflows[0]['owner']['name']).to eq @user['name']
    end

    it 'returns a root name' do
      expect(@workflows[0]['root_names'][0]).to eq @w2.jobs.last.name
    end

    context 'default scope' do
      let!(:one) { create(:workflow) }
      let!(:two) { create(:workflow) }
      let!(:three) { create(:workflow) }

      it 'orders by descending updated_at' do
        two.touch
        expect(Workflow.first).to eq three
      end
    end

    context 'get records using the by_status scope' do
      before do
        browser.get '/', {by_status: 'queued'}, {'Content-Type' => 'application/json', 'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
      end

      it 'is successful' do
        expect(browser.last_response.status).to eq 200
      end

      it 'returns workflows with matching status' do
        workflows = JSON.parse(browser.last_response.body)
        expect(workflows.count).to eq(1)
        expect(workflows[0]['id']).to eq @w2.id
      end
    end

    context 'get records using the by_uuid scope' do
      before do
        browser.get '/', {by_uuid: @w1.uuid}, {'Content-Type' => 'application/json', 'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
      end

      it 'is successful' do
        expect(browser.last_response.status).to eq 200
      end

      it 'returns workflows with matching uuid' do
        workflows = JSON.parse(browser.last_response.body)
        expect(workflows.count).to eq(1)
        expect(workflows[0]['id']).to eq @w1.id
      end
    end

    context 'get records using the by_user_oauth_id scope' do
      before do
        @w1 = create(:workflow, user_oauth_id: 123)
        @w2 = create(:workflow, user_oauth_id: 123)
        @w3 = create(:workflow, user_oauth_id: 789)
        @w4 = create(:workflow, user_oauth_id: 789)

        stub_request(:get, "#{ENV['USERS_URL']}/users/789").
          with(:headers => {'Accept'=>'application/json'}).
          to_return(:status => 200, :body => {"oauth_id":"108707085","name":"Carlo Camporesi"}.to_json, :headers => {})

        browser.get '/', {by_user_oauth_id: 789}, {'Content-Type' => 'application/json', 'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
      end

      it 'is successful' do
        expect(browser.last_response.status).to eq 200
      end

      it 'returns workflows for the user_oauth_id' do
        workflows = JSON.parse(browser.last_response.body)

        expect(workflows.count).to eq(2)
        expect(workflows[0]['id']).to eq @w4.id
        expect(workflows[1]['id']).to eq @w3.id
      end
    end

    context 'get records with job counts' do
      let!(:thrid_job) { create(:job) }

      before :each do
        browser.get '/', {}, {'Content-Type' => 'application/json', 'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
      end

      it 'is successful' do
        expect(browser.last_response.status).to eq 200
      end

      it 'returns workflows which allow access to job status counts' do
        workflows = JSON.parse(browser.last_response.body)
        #pp JSON.parse browser.last_response.body
        expect(workflows[0]['jobs_queued_count']).to eq 0
        expect(workflows[1]['jobs_queued_count']).to eq 0
        expect(workflows[2]['jobs_queued_count']).to eq 0
        expect(workflows[0]['jobs_running_count']).to eq 1
        expect(workflows[1]['jobs_running_count']).to eq 0
        expect(workflows[2]['jobs_running_count']).to eq 0
        expect(workflows[0]['jobs_waiting_count']).to eq 4
        expect(workflows[0]['jobs_waiting_count']).to eq 4
        expect(workflows[1]['jobs_waiting_count']).to eq 4
        expect(workflows[0]['jobs_total_count']).to eq 5
        expect(workflows[1]['jobs_total_count']).to eq 4
        expect(workflows[2]['jobs_total_count']).to eq 4
      end
    end

  end
end

