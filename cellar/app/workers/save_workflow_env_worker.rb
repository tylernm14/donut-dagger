require 'json'
require 'restclient'
require 'timeout'
require_relative '../lib/zip_file_generator'
require_relative '../models/workflow_env'

class SaveWorkflowEnvWorker
  include Sidekiq::Worker
  sidekiq_options queue: :save_workflow_env, retry: true, backtrace: true

  SHARED_FS_MOUNT_PATH = ENV['SHARED_FS_MOUNT_PATH'] || '/srv'
  SHARED_WORKFLOWS_PATH = File.join(SHARED_FS_MOUNT_PATH, 'workflows')

  def perform(workflow_env_id)
    @wenv = WorkflowEnv.find(workflow_env_id)
    begin
      save_zip(@wenv.workflow_uuid)
    rescue Exception => e
      @wenv.update(status: :failed)
      raise e
    end
  end

  private

  def save_zip(workflow_uuid)
    @wenv.update!(status: :saving)
    Dir.mktmpdir do |dir|
      zip_path = make_zip(dir, workflow_uuid)
      @wenv.update!(status: :saved, zip_file: File.open(zip_path, 'r'))
    end
  end

  def make_zip(tmpdir, workflow_uuid)
    dir_to_zip = File.join(SHARED_WORKFLOWS_PATH, workflow_uuid)
    unless File.directory?(dir_to_zip)
      raise "Workflow directory '#{dir_to_zip}' doesn't exist."
    end
    zip_path = File.join(tmpdir, "#{workflow_uuid}.zip")
    zip = ZipFileGenerator.new(dir_to_zip, zip_path)
    zip.write
    zip_path
  end

end