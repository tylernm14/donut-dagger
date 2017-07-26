class CreateWorkflowsAndDefinitions < ActiveRecord::Migration
  def change

     create_table :definitions do |t|
      t.string :name, null: false, index: true, unique: true
      t.string :description
      t.jsonb :data, null: false, default: {}
      t.timestamps null: false
     end

    create_table :workflows do |t|
      t.uuid  :uuid, null: false, index: true
      t.integer :status, null: false, default: 0, index: true
      t.integer :priority, null: false, default: 0
      t.integer :user_oauth_id
      t.string :queue
      t.string :proc_queue
      t.string :messages, array: true, default: []
      t.uuid  :root_job_uuid
      t.integer :parallelism, null: false, default: 1
      t.integer :launched_jobs_count, null: false, default: 0
      t.datetime :start_time
      t.datetime :end_time
      t.timestamps null: false
      t.belongs_to :definition, index: true, null: false
    end
  end
end
