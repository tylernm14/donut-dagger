require 'spec_helper'

describe DefinitionsController, :type => :controller do
  let(:app) { DefinitionsController }
  let(:browser) { Rack::Test::Session.new(Rack::MockSession.new(DefinitionsController, 'myapp.dev')) }

  before do
    Definition.destroy_all
    stub_user_token
  end

  describe 'GET /' do

    before do
      @w1 = create(:definition)
      @w2 = create(:definition)
      browser.get '/', {}, {'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
      @definitions = JSON.parse(browser.last_response.body)
    end

    it 'is successful' do
      expect(browser.last_response.status).to eq 200
    end

    it 'returns worflow definitions' do
      expect(@definitions.count).to eq(2)
    end

  end

  describe 'POST /' do
    context "with valid params" do
      before do
        @attributes = FactoryGirl.attributes_for(:definition)

        expect {
          browser.post '/', @attributes.to_json, {'Content-Type' => 'application/json', 'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
        }.to change(Definition, :count).by(1)
      end
      it 'is successful' do
        expect(browser.last_response.status).to eq 200
      end
      it 'returns workflow definition' do
        definition = JSON.parse(browser.last_response.body)
        expect(definition['name']).to eq(@attributes[:name])
      end
    end
  end

  describe 'GET /:id' do

    before do
      @w1 = create(:definition)
      @w2 = create(:definition)
      browser.get "/#{@w1.id}", {}, {'Content-Type' => 'application/json', 'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
      @definition = JSON.parse(browser.last_response.body)
    end

    it 'is successful' do
      expect(browser.last_response.status).to eq 200
    end

    it 'returns workflow' do
      expect(@definition['id']).to eq(@w1.id)
    end


  end

  describe 'UPDATE /:id' do

    context 'when record present' do

      before do
        @w = create(:definition)
        payload = @w.as_json
        payload[:description] = "testing"
        browser.put "/#{@w.id}", payload.to_json, {'Content-Type' => 'application/json', 'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
      end

      it 'is successful' do
        expect(browser.last_response.status).to eq 200
        expect(Definition.last.description).to eq('testing')
      end

      it 'returns definition' do
        wfd = JSON.parse(browser.last_response.body)
        expect(wfd['id']).to eq(@w.id)
        expect(wfd['description']).to eq('testing')
      end

    end

    context 'with invalid params' do
      before do
        @w = create(:definition)
        payload = @w.as_json
        payload['parameters'] = {'test':'test'}
        payload[:description] = "testing"
        browser.put "/#{@w.id}", payload.to_json, {'Content-Type' => 'application/json', 'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
      end

      it 'is successful' do
        expect(browser.last_response.status).to eq 200
        expect(Definition.last.description).to eq('testing')
      end

    end

  end

  describe 'DELETE /:id' do

    context 'when record present' do

      before do
        @w = create(:definition)
        browser.delete "/#{@w.id}", {}, {'Content-Type' => 'application/json', 'HTTP_AUTHORIZATION' => 'Token token=devtoken'}
      end

      it 'is successful' do
        expect(browser.last_response.status).to eq 200
        expect(Definition.last).to be_falsy
      end

      it 'deletes a definition' do
        expect{Definition.find(@w.id)}.to raise_exception(ActiveRecord::RecordNotFound)
      end

    end

  end

end