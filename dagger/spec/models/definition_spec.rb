require 'spec_helper'

describe Definition, type: :model do
  subject { create(:definition) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:data) }
  it { is_expected.to have_many(:workflows).dependent(:destroy) }



  context 'unique validations' do
    subject { build(:definition) }

    it { is_expected.to validate_uniqueness_of(:name) }
  end

  before do
    Definition.destroy_all
    stub_user_token
  end

  let(:app) { DefinitionsController }
  let(:browser) { Rack::Test::Session.new(Rack::MockSession.new(DefinitionsController, 'myapp.dev')) }

  describe "with scopes" do
    before do
      @one = create(:definition)
      @two = create(:definition)
      @three = create(:definition)
    end

    context 'default' do
      it 'orders by descending name' do
        @two.touch
        expect(Definition.first).to eq @one
      end
    end

    context 'by_name' do
      before do
        browser.get '/', { by_name: @two.name },  { 'HTTP_AUTHORIZATION' => 'Token token=devtoken' }
      end

      it { browser.last_response.status == 200 }
      it 'returns a definition' do
        work_def = JSON.parse(browser.last_response.body)

        expect(work_def.count).to eq(1)
        expect(work_def[0]['id']).to eq @two.id
      end
    end
  end
end