require 'spec_helper'

RSpec.describe FindOrCreateDefinition do

  describe '#call' do

    before do
      Definition.destroy_all
    end

    context 'with definition id' do
      before do
        @definition = create(:definition)
        @payload = FactoryGirl.attributes_for(:workflow).merge(definition_id: @definition.id)
        @payload.delete(:definition)
        @payload.stringify_keys!
      end

      it 'should return the existing workflow definition' do
        expect {
          expect(FindOrCreateDefinition.call(@payload).id).to be @definition.id
        }.to change(Definition, :count).by 0
      end

    end

    context 'with definition name' do
      before do
        @definition = create(:definition)
        @payload = FactoryGirl.attributes_for(:workflow).merge(definition_name: @definition.name)
        @payload.delete(:definition)
        @payload.stringify_keys!
      end

      it 'should return the existing workflow definition' do
        expect {
          expect(FindOrCreateDefinition.call(@payload).id).to be @definition.id
        }.to change(Definition, :count).by 0
      end

    end

    context 'with data' do
      before do
        @definition = build(:definition)
        @payload = FactoryGirl.attributes_for(:workflow).merge(data: @definition.data.to_json)
        @payload.delete(:definition)
        @payload.stringify_keys!
      end

      it 'should return a new workflow definition' do
        expect {
          wdef = FindOrCreateDefinition.call(@payload)
          expect(wdef.name).to eq '1d010f64004b62901ea003aa483d8b09ab7dbdf53a2d08be7bdf1a2d5d1fc8f2'
          expect(wdef.description).to eq ''
        }.to change(Definition, :count).by 1
      end

    end

    context 'with data and description' do
      before do
        @definition = build(:definition)
        @payload = FactoryGirl.attributes_for(:workflow).merge(data: @definition.data.to_json, description: 'blast off')
        @payload.delete(:definition)
        @payload.stringify_keys!
      end

      it 'should return a new workflow definition' do
        expect {
          wdef = FindOrCreateDefinition.call(@payload)
          expect(wdef.name).to eq '1d010f64004b62901ea003aa483d8b09ab7dbdf53a2d08be7bdf1a2d5d1fc8f2'
          expect(wdef.description).to eq 'blast off'
        }.to change(Definition, :count).by 1
      end

    end

    context 'with data that already exists' do
      before do
        @definition = create(:definition, name: '1d010f64004b62901ea003aa483d8b09ab7dbdf53a2d08be7bdf1a2d5d1fc8f2')
        @payload = FactoryGirl.attributes_for(:workflow).merge(data: @definition.data.to_json)
        @payload.delete(:definition)
        @payload.stringify_keys!
      end

      it 'should return existing workflow definition' do
        expect {
          expect(FindOrCreateDefinition.call(@payload).id).to be @definition.id
        }.to change(Definition, :count).by 0
      end

    end

    context 'with invalid data' do
      before do
        @definition = build(:definition_empty_data)
        @payload = FactoryGirl.attributes_for(:workflow).merge(data: @definition.data.to_json)
        @payload.delete(:definition)
        @payload.stringify_keys!
      end

      it 'raise error' do
        expect {
          expect(FindOrCreateDefinition.call(@payload))
        }.to raise_error(InvalidDefinitionError).and change(Definition, :count).by 0
      end

    end

  end
end