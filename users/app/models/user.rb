require 'sinatra/activerecord'
require 'securerandom'
require_relative 'token'


class User < ActiveRecord::Base
  default_scope { order('created_at desc') }
  scope :by_token,   -> (token)   { where token: Token.find_by(value: token).id }

  has_many :tokens

  def self.from_oauth(user)
    current_user = User.find_by(oauth_id: user.id)
    if current_user.nil?
      puts user.inspect
      current_user = User.create!(login: user.login,
                   oauth_id: user.id.to_i,
                   name: user.name,
                   email: user.email
    )
      Token.create( user: current_user )
    end
    current_user
  end
end