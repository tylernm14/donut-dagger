class AddLocalInputs < ActiveRecord::Migration
  def change
    create_table :local_inputs do |t|
      t.string :name, null: false
      t.string :file, null: false
      t.integer :file_size, null: false
      t.string :file_content_type, null: false
      t.string :dest_path, default: '.', null: false
      t.string :workflow_uuid, null: false
      t.timestamps null: false
    end
  end
end
