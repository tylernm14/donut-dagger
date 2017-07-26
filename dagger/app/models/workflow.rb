require 'sinatra/activerecord'
require_relative '../services/create_dag_jobs'
require_relative 'job'
require_relative 'user'
require_relative '../workers/start_workflow_worker'

class Workflow < ActiveRecord::Base
  ActiveRecord::Base.raise_in_transactional_callbacks = true

  attr_readonly :uuid

  enum status: [:bootstrap, :queued, :running, :done, :failed, :dead, :terminated]
  enum priority: [:normal, :critical]

  default_scope { order('created_at desc') }

  scope :by_status, -> (status) { where status: Workflow.statuses[status] }
  scope :by_user_oauth_id, -> (user_oauth_id) { where user_oauth_id: user_oauth_id }
  scope :by_uuid, -> (uuid) { where uuid: uuid }

  belongs_to :definition
  has_many :jobs, dependent: :destroy
  has_many :roots, dependent: :destroy

  validates_presence_of :status
  validates_presence_of :parallelism


  attr_accessor :requested_count, :failed_count, :completed_count

  #after_update :launch_terminate_worker, if: :status_changed?

  # used to fix the uuid generation
  # Want to create job info before workflow record gets persisted
  before_validation :create_uuid, on: :create
  after_create :create_dag_jobs

  Job.statuses.each do |s|
    define_method "jobs_#{s.first}_count" do
      Job.where(workflow_id: self.id).where("status = ?", s.second).size
    end
  end

  def jobs_total_count
    self.jobs.size
  end

  def all_jobs_completed?
    !(self.jobs.map(&:status) & ['queued', 'waiting', 'running']).any?
  end

  def owner
    unless self.user_oauth_id.nil?
      u = User.find(self.user_oauth_id)
    end
  end

  def root_names
    self.roots.map {|r| Job.find(r.job.id).name }
  end

  def completed?
    done? or failed? or dead? or terminated?
  end

  def result_count
    begin
      Result.all(params: { by_workflow_id: self.id }).count
    rescue StandardError => e
      -1
    end
  end

  private

  def create_dag_jobs
    self.reload # get uuid created by postgres
    CreateDagJobs.call(self)
    StartWorkflowWorker.perform_async(self.id)
  end

  def create_uuid
    unless self.uuid
      self.uuid = SecureRandom.uuid
    end
  end

  #def launch_worker
    #update_columns(status: Workflow.statuses[:queued])
    #WorkflowRunWorker.perform_async(self.id)
  #end

  #def launch_terminate_worker
    #if self.terminated?
      #WorkflowTerminateWorker.perform_in(10.seconds, self.id)
    #end
  #end


end
