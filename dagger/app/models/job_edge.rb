require 'sinatra/activerecord'

class JobEdge < ActiveRecord::Base
  ActiveRecord::Base.raise_in_transactional_callbacks = true

  default_scope { order('created_at desc') }
  scope :by_workflow_id, -> (id) { where workflow_id: id }
  scope :by_dependency_id, -> (id) {where dependency_id: id}
  scope :by_dependent_id, -> (id) {where dependent_id: id}

  belongs_to :workflow
  belongs_to :dependency, class_name: 'Job', counter_cache: :dependents_count
  belongs_to :dependent, class_name: 'Job', counter_cache: :dependencies_count

  validates_presence_of :workflow_id, :dependency_id, :dependent_id
end
