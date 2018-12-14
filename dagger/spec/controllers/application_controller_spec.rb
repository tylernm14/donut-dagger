require 'spec_helper'

describe ApplicationController, :type => :controller do
  # let(:browser) { Rack::Test::Session.new(Rack::MockSession.new(ApplicationController, 'myapp.dev')) }
  def app
    ApplicationController
  end
  before do
    browser_sign_in
  end

  context 'base' do
    it 'GET responds with 404 json not found paths' do
      get '/not-there'
      expect(last_response.status).to eq 404
    end

    it 'POST responds with 404 json not found paths' do
      post '/not-there'
      expect(last_response.status).to eq 404
    end

    it 'PUT responds with 404 json not found paths' do
      put '/not-there'
      expect(last_response.status).to eq 404
    end

    it 'PATCH responds with 404 json not found paths' do
      patch '/not-there'
      expect(last_response.status).to eq 404
    end

    it 'DELETE responds with 404 json not found paths' do
      delete '/not-there'
      expect(last_response.status).to eq 404
    end
  end

  # NOTE: Need to figure out how to fake logged in user session
  context '/home' do
    before do

      get '/home'
    end
    it 'is successful' do
      expect(last_response.status).to eq 200
    end

    it 'renders links' do
      expect(last_response.body).to match(/href='\/workflows'/)
#      expect(last_response.body).to match(/href='\/local_inputs'/)
#      expect(last_response.body).to match(/href='\/workflow_envs'/)
      expect(last_response.body).to match(/href='\/tokens'/)
      expect(last_response.body).to match(/href='\/healthcheck\/complete'/)
      expect(last_response.body).to match(/href='\/sidekiq'/)
      expect(last_response.body).to match(/href='\/logout'/)
      expect(last_response.body).to match(/Workflows/)
#      expect(last_response.body).to match(/Local Inputs/)
#      expect(last_response.body).to match(/Workflow Envs/)
      expect(last_response.body).to match(/Your API Tokens/)
      expect(last_response.body).to match(/Health Check/)
      expect(last_response.body).to match(/Sidekiq/)
      expect(last_response.body).to match(/Logout/)
    end
  end

  context '/' do
    before do
      get '/'
    end
    it 'is successful' do
      expect(last_response.status).to eq 302
      expect(last_response).to be_redirect
      follow_redirect!
      expect(last_request.url).to match /workflows\/admin/
    end
  end
end
