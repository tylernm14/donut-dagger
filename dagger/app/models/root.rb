require 'sinatra/activerecord'

class Root < ActiveRecord::Base

  ActiveRecord::Base.raise_in_transactional_callbacks = true

  default_scope { order('created_at desc') }
  belongs_to :workflow
  belongs_to :job

  validates_presence_of :workflow, :job

end
