require 'sinatra/activerecord'

class Definition < ActiveRecord::Base
  ActiveRecord::Base.raise_in_transactional_callbacks = true

  default_scope { order(:name, updated_at: :desc) }

  scope :by_name, -> (name) { where name: name }

  validates_presence_of :name, :data
  validates_uniqueness_of :name

  has_many :workflows, dependent: :destroy

  attr_reader :parameters

end