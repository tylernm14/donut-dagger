require 'spec_helper'
require 'pp'

describe JobsController, :type => :controller do
  let(:app) { JobsController }
  let(:browser) { Rack::Test::Session.new(Rack::MockSession.new(JobsController, 'myapp.dev')) }

  before do
    Workflow.destroy_all
    stub_user_token
    @redis_conn = double('redis_conn')
    allow_any_instance_of(ConnectionPool).to receive(:with).and_yield(@redis_conn)
    allow(@redis_conn).to receive(:lpush)
  end

  describe 'GET /' do
    before do
      # Dont create the initial jobs in the dag of our factory workflow
      allow(CreateDagJobs).to receive(:call).with(any_args)
      @w = create(:workflow)
      @j1 = create(:job, workflow_id: @w.id)
      @j2 = create(:job, workflow_id: @j1.workflow.id, status: :failed)
      browser.get '/', {}, {'Content-Type' => 'application/json', 'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
      @jobs = JSON.parse(browser.last_response.body)
    end

    it 'is successful' do
      expect(browser.last_response.status).to eq 200
    end

    it 'returns jobs' do
      expect(@jobs.count).to eq(2) # Workflow create always creates the jobs in the definition data
      expect(@jobs[1]['uuid']).to eq(@j1.uuid)
      expect(@jobs[0]['uuid']).to eq(@j2.uuid)
    end

    context 'default scope' do
      let!(:one) { create(:job) }
      let!(:two) { create(:job) }
      let!(:three) { create(:job) }

      it 'orders by descending updated_at' do
        two.touch
        expect(Job.first).to eq three
      end
    end

    context 'get records using the by_status scope' do
      before do
        browser.get '/', {by_status: 'failed'}, {'Content-Type' => 'application/json', 'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
      end

      it 'is successful' do
        expect(browser.last_response.status).to eq 200
      end

      it 'returns jobs' do
        jobs = JSON.parse(browser.last_response.body)
        expect(jobs.count).to eq(1)
        expect(jobs[0]['id']).to eq @j2.id
      end
    end


    context 'get records using the by_uuid scope' do
      before do
        browser.get '/', {by_uuid: @j1.uuid}, {'Content-Type' => 'application/json', 'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
      end

      it 'is successful' do
        expect(browser.last_response.status).to eq 200
      end

      it 'returns jobs' do
        jobs = JSON.parse(browser.last_response.body)
        expect(jobs.count).to eq(1)
        expect(jobs[0]['id']).to eq @j1.id
      end
    end
    context 'with associated jobs' do
      before do
        @job = create(:job)
        @dependent_job = create(:job)
        @dependency_job = create(:job)
        create(:job_edge, workflow: @job.workflow, dependency: @dependency_job, dependent: @job)
        create(:job_edge, workflow: @job.workflow, dependency: @job, dependent: @dependent_job)
        browser.get '/', {by_uuid: @job.uuid}, {'Content-Type' => 'application/json', 'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
        @jobs = JSON.parse(browser.last_response.body)
      end
      it 'return jobs with uuid of dependencies and dependent jobs' do
        expect(@jobs.first['dependencies'].first['uuid']).to eq(@dependency_job.uuid)
        expect(@jobs.first['dependents'].first['uuid']).to eq(@dependent_job.uuid)
      end
    end
  end


  describe 'POST /' do

    context 'no dependency jobs' do
      before do
        @attributes = FactoryGirl.build(:job).attributes
        @attributes[:workflow_uuid] = Workflow.find(@attributes['workflow_id']).uuid
        expect {
          browser.post '/', @attributes.to_json, {'Content-Type' => 'application/json', 'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
        }.to change(Job, :count).by(1)
      end
      it 'is successful' do
        expect(browser.last_response.status).to eq 200
        expect(Job.first.status).to eq('running')
      end
      it 'returns job' do
        job = JSON.parse(browser.last_response.body)
        expect(job['status']).to eq('running')
      end
    end

    context 'with parent job' do
      before do
        @dependency_job_uuid1 = create(:job)[:uuid]
        @dependency_job_uuid2 = create(:job)[:uuid]
        @attributes = FactoryGirl.build(:job).attributes
        @attributes[:workflow_uuid] = Workflow.find(@attributes['workflow_id']).uuid
        @attributes[:dependencies] = [{
                                     uuid: @dependency_job_uuid1
                                 }]
        browser.post '/', @attributes.to_json, {'Content-Type' => 'application/json', 'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
      end
      it 'creates a job with dependency uuid' do
        job = JSON.parse(browser.last_response.body)
        expect(job['dependencies'].first['uuid']).to eq(@dependency_job_uuid1)
      end
    end

    context 'no workflow uuid' do
      before do
        @attributes = FactoryGirl.build(:job).attributes
        @attributes[:workflow_uuid] = 'no-valid'
        expect {
          browser.post '/', @attributes.to_json, {'Content-Type' => 'application/json', 'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
        }.to change(Job, :count).by(0)
      end
      it 'should return not found' do
        expect(browser.last_response.status).to eq 404
      end
    end

  end

  describe 'GET /:id' do
    before do
      @j1 = create(:job)
      @j2 = create(:job)
      browser.get "/#{@j1.id}", {}, {'Content-Type' => 'application/json', 'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
      @job = JSON.parse(browser.last_response.body)
    end

    it 'is successful' do
      expect(browser.last_response.status).to eq 200
    end

    it 'returns job' do
      expect(@job['id']).to eq(@j1.id)
    end

    context 'with associated jobs' do
      before do
        @job = create(:job)
        @dependent_job = create(:job)
        @dependency_job = create(:job)
        create(:job_edge, workflow: @job.workflow, dependency: @dependency_job, dependent: @job)
        create(:job_edge, workflow: @job.workflow, dependency: @job, dependent: @dependent_job)
        browser.get "/#{@job.id}", {by_uuid: @job.uuid}, {'Content-Type' => 'application/json', 'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
        @returned_job= JSON.parse(browser.last_response.body)
      end
      it 'return jobs with uuid of parents and children jobs' do
        expect(@returned_job['dependencies'].first['uuid']).to eq(@dependency_job.uuid)
        expect(@returned_job['dependents'].first['uuid']).to eq(@dependent_job.uuid)
      end
    end

    it 'returns workflow' do
      expect(@job['workflow']).not_to be nil
    end
  end

  describe 'UPDATE /:id' do
    context 'when record present' do
      before do
        @job = create(:job)
        stub_request(:get, "#{ENV['CELLAR_URL']}/results?by_job_id=#{@job.id}").
            with(headers: {'Accept'=>'application/json'}).
            to_return(status: 200, body: "", headers: {})
        @job.status = Job.statuses[:failed]
        browser.put "/#{@job.id}", @job.to_json, {'Content-Type' => 'application/json', 'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
      end

      it 'is successful' do
        expect(browser.last_response.status).to eq 200
        expect(Job.first.status).to eq('failed')
      end

      it 'updates status' do
        expect(@job.failed?).to be true
      end

      it 'returns job' do
        job = JSON.parse(browser.last_response.body)
        expect(job['id']).to eq(@job.id)
        expect(job['status']).to eq('failed')
      end

    end

  end

end
