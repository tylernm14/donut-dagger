class CreateJobs < ActiveRecord::Migration
  def change
    create_table :jobs do |t|

      t.belongs_to :workflow, null: false, index: true
      t.uuid :uuid, null: false, index: true
      t.string :name, null: false
      t.jsonb :description, null: false, default: {}
      t.integer :status, null: false, default: 0, index: true
      t.integer :priority, null: false, default: 0
      t.integer :dependencies_count, null: false, default: 0
      t.integer :dependencies_succeeded_count, null: false, default: 0
      t.integer :dependents_count, null: false, default: 0
      t.text :stdout, default: ''
      t.text :stderr, default: ''
      t.text :messages, default: ''
      t.datetime :start_time
      t.datetime :end_time
      t.timestamps null: false
    end
  end
end
