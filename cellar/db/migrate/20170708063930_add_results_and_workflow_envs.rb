class AddResultsAndWorkflowEnvs < ActiveRecord::Migration
  def change
    create_table :results do |t|
      t.belongs_to :workflow, index: true, null: false
      t.belongs_to :job, index: true, null: false
      t.string :name, index: true, null: true
      t.string :job_name, null: false
      t.string :file, null: false
      t.string :file_content_type, null: false
      t.integer :file_size, null: false
      # t.integer :workflow_id, null: false, index: true
      # t.integer :job_id, null: false, index: true
      t.jsonb :metadata, null: false, default: '{}'
      t.timestamps null: false
    end
    add_index :results, :metadata, using: :gin

    create_table :workflow_envs do |t|
      t.string :workflow_uuid, index: true, null: false
      t.string :zip_file, null: true
      t.integer :zip_file_size, null: true
      t.integer :status, null: false, default: 0
      t.timestamps null: false
    end
  end
end
