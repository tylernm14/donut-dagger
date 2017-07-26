require 'sinatra/activerecord'
require_relative 'user'
require 'securerandom'

class Token < ActiveRecord::Base
  default_scope { order('created_at desc') }
  scope :by_value,   -> (value)   { where value: value }
  scope :by_user_id, ->(user_id) { where user_id: user_id}

  belongs_to :user

  validates :value, uniqueness: true

  before_create :gen_token_value

  private

  def gen_token_value
    if self.value.nil?
      self.value = SecureRandom.hex(32)
    end
  end

end