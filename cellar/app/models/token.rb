require 'active_resource'

class Token < ActiveResource::Base
  self.timeout = 10
  self.site = "#{ENV['USERS_URL']}"
  self.element_name = 'token'
  self.include_format_in_path = false
  self.headers['Authorization'] = "Token token=#{ENV['ADMIN_TOKEN']}"
end