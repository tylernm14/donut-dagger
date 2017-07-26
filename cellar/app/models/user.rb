require 'active_resource'
require 'json'

class User < ActiveResource::Base
  self.timeout = 10
  self.site = "#{ENV['USERS_URL']}"
  self.element_name = 'user'
  self.include_format_in_path = false
  headers['Authorization'] = "Token token=#{ENV['ADMIN_TOKEN']}"

  def self.from_oauth(authed_user)
    begin
      user = self.find(authed_user.id)
    rescue ActiveResource::ResourceNotFound
      user = self.new
      user.login = authed_user.login
      user.oauth_id = authed_user.id
      user.email = authed_user.email
      user.name = authed_user.name
      user.avatar_url = authed_user.avatar_url
      user.save!
      user
    end
  end
end