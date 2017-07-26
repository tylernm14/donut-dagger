class CreateJobEdges < ActiveRecord::Migration
  def change
    create_table :job_edges do |t|
      t.belongs_to :workflow, index: true, null: false
      t.belongs_to :dependency, index: true, null: false
      t.belongs_to :dependent, index: true, null: false
      t.timestamps null: false
    end
  end
end
