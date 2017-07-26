require 'sinatra/activerecord'
require_relative '../uploaders/file_uploader'
require_relative '../workers/save_workflow_env_worker'

class WorkflowEnv < ActiveRecord::Base
  ActiveRecord::Base.raise_in_transactional_callbacks = true

  enum status: [ :saving, :saved, :failed ]

  default_scope { order('created_at desc') }
  scope :by_workflow_uuid,   -> (uuid)       { where workflow_uuid: uuid }

  validates_presence_of :workflow_uuid

  mount_uploader :zip_file, FileUploader

  after_commit :save_workflow_env, on: :create

  private

  def save_workflow_env
    SaveWorkflowEnvWorker.perform_async(self.id)
  end


end