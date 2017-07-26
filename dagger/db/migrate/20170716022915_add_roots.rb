class AddRoots < ActiveRecord::Migration
  def change
    create_table :roots do |t|
      t.belongs_to :workflow, index: true, null: false
      t.belongs_to :job, index: true, null: false
      t.timestamps null: false
    end
  end
end
