require_relative '../models/definition'
require 'active_record'
require 'yaml'

class EmptyDataError < StandardError
end
class InvalidDefinitionError < StandardError
end

class FindOrCreateDefinition

  def self.call(payload)
    payload = payload.symbolize_keys

    if payload.has_key?(:definition_id)
      definition = Definition.find(payload.fetch(:definition_id))
    elsif payload.has_key?(:definition_name)
      definition = Definition.find_by_name!(payload.fetch(:definition_name))
    else
      sha = self.data_to_sha(payload.fetch(:data))
      definition = Definition.find_by_name(sha)
      if definition.nil?
        data = payload.fetch(:data)
        puts "DATA: #{data}"
        unless data.empty?
          begin
            hash_data = JSON.parse(data)
          rescue JSON::ParserError
            hash_data = YAML.load(data)
          end
          if self.valid_definition_data?(hash_data)
            definition = Definition.create!(name: sha, data: hash_data, description:  payload[:description] || '')
          else
            puts 'Invalid workflow definition'
            raise InvalidDefinitionError.new('Invalid workflow definition')
          end
        else
          raise EmptyDataError.new("Data can't be empty object")
        end
      end
    end
    definition
  end

  private

  def self.valid_definition_data?(data)
    data['jobs'] && data['neighbors']
  end

  def self.root_job_in_jobs_array?(data)
    data['jobs'].map { |j| j['name']}.include? data['root']
  end

  def self.data_to_sha(data)
    Digest::SHA256.hexdigest(ActiveSupport::JSON.encode(data))
  end

end
