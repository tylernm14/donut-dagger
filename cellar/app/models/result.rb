require 'sinatra/activerecord'
require_relative '../uploaders/attachment_uploader'

class Result < ActiveRecord::Base
  ActiveRecord::Base.raise_in_transactional_callbacks = true

  default_scope { order('updated_at desc') }
  scope :by_job_id,        -> (id)       { where job_id: id }
  scope :by_workflow_id,   -> (id)       { where workflow_id: id }
  # scope :by_metadata,      -> (params)   { where 'metadata @> ?', params }
  # scope :search,           -> (term)     { where('EXISTS (SELECT 1 FROM results_metadata_matview m WHERE m.id = results.id AND m.data ILIKE ?)', "%#{term}%")}

  validates_presence_of :file, :workflow_id, :job_id

  mount_uploader :file, AttachmentUploader

  # after_commit -> {Result.refresh_view}
  #
  # private
  #
  # def self.refresh_view
  #   connection = ActiveRecord::Base.connection
  #   connection.execute('REFRESH MATERIALIZED VIEW results_metadata_matview')
  # end
end