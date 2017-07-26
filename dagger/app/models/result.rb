require 'active_resource'
require 'activeresource-response'


class Result < ActiveResource::Base
  self.timeout = 10
  self.site = ENV['CELLAR_URL']
  self.include_format_in_path = false
  self.headers['Authorization'] = "Token token=#{ENV['ADMIN_TOKEN']}"
  add_response_method :http_response

  # ActiveResource creates either a new resource or a new class for
  # nested hashes.  Nested hassh for a carrierwave file is returned
  # so we define our own class so that ActiveResources doesnt try to
  # instantiate a regular File class used  for IO

  class File < ActiveResource::Base
    # attr_accessor :thumb
    def initialize(attributes = {}, persisted = false)
      @attributes     = attributes.with_indifferent_access
      @prefix_options = {}
      @persisted = persisted
    end
  end
end