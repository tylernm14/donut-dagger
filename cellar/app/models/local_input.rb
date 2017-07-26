require 'sinatra/activerecord'
require_relative '../uploaders/attachment_uploader'

class LocalInput < ActiveRecord::Base
  ActiveRecord::Base.raise_in_transactional_callbacks = true

  default_scope { order('updated_at desc') }
  scope :by_workflow_uuid,   -> (uuid)       { where workflow_uuid: uuid }

  validates_presence_of :file, :workflow_uuid, :dest_path

  mount_uploader :file, AttachmentUploader
end