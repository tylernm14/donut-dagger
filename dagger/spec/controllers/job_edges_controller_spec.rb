require 'spec_helper'

describe JobEdgesController, :type => :controller do
  let(:app) { JobEdgesController }
  let(:browser) { Rack::Test::Session.new(Rack::MockSession.new(JobEdgesController, 'myapp.dev')) }

  before do
    JobEdge.destroy_all
    stub_user_token
  end

  describe 'GET /' do
    before do
      @w = create(:workflow)
      @job_edge1 = create(:job_edge, workflow: @w)
      @job_edge2 = create(:job_edge, workflow: @w)
      @job_edge3 = create(:job_edge, workflow: @w)
      browser.get '/', {}, {'Content-Type' => 'application/json', 'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
      @job_edges = JSON.parse(browser.last_response.body)
    end

    it 'is successful' do
      expect(browser.last_response.status).to eq 200
    end

    it 'returns job edges' do
      expect(@job_edges.count).to eq(7)
      expect(@job_edges[2]['dependency_id']).to eq(@job_edge1.dependency_id)
      expect(@job_edges[1]['dependency_id']).to eq(@job_edge2.dependency_id)
    end

  end


  describe 'POST /' do
    context 'with all required parameters' do
      before do
        @attrs = FactoryGirl.attributes_for(:job_edge).merge({workflow_id: 1})
        puts @attrs
        @incomplete_attrs = FactoryGirl.attributes_for(:job_edge).delete("dependent_id")

        expect {
          browser.post '/', @attrs.to_json, {'Content-Type' => 'application/json', 'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
        }.to change(JobEdge, :count).by(1)
      end
      it 'is successful' do
        expect(browser.last_response.status).to eq 200
        expect(JobEdge.last.dependency_id).to eq(@attrs[:dependency_id])
        expect(JobEdge.last.dependent_id).to eq(@attrs[:dependent_id])
      end
      it 'returns job_edge' do
        job_edge = JSON.parse(browser.last_response.body)
        expect(job_edge['dependency_id']).to eq(@attrs[:dependency_id])
        expect(job_edge['dependent_id']).to eq(@attrs[:dependent_id])
      end
    end
    context 'without all required parameters' do
      before do
        @incomplete_attrs = FactoryGirl.attributes_for(:job_edge)
        @incomplete_attrs.delete(:dependent_id)
        expect {
          browser.post '/', @incomplete_attrs.to_json, {'Content-Type' => 'application/json', 'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
        }.to change(JobEdge, :count).by(0)
      end
      it 'return an error' do
        expect(browser.last_response.status).to eq 422
      end
    end

  end

  describe 'GET /:id' do
    before do
      @job_edge1 = create(:job_edge)
      @job_edge2 = create(:job_edge)
      @job_edge3 = create(:job_edge)
      browser.get "/#{@job_edge1.id}", {}, {'Content-Type' => 'application/json', 'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
      @job_edges = JSON.parse(browser.last_response.body)
    end

    it 'is successful' do
      expect(browser.last_response.status).to eq 200
    end

    it 'returns job' do
      expect(@job_edge1['id']).to eq(@job_edge1.id)
    end
  end

  describe 'UPDATE /:id' do
    context 'when record present' do
      before do
        @job_edge1 = create(:job_edge)
        payload = @job_edge1.as_json
        payload[:dependent_id] = 20
        browser.put "/#{@job_edge1.id}", payload.to_json, {'Content-Type' => 'application/json', 'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
      end

      it 'is successful' do
        expect(browser.last_response.status).to eq 200
        expect(JobEdge.all.last.dependent_id).to eq(20)
      end

      it 'returns job edge' do
        job_edge = JSON.parse(browser.last_response.body)
        expect(job_edge['id']).to eq(@job_edge1.id)
        expect(job_edge['dependent_id']).to eq(20)
      end
    end
  end

end

