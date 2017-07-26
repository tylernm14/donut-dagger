class CreateUsersAndTokens < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :login, null: false, index: true, unique: true
      t.string :email, null: false, index: true, unique: true
      t.integer :oauth_id, null: true, index: true, unique: true
      t.string :name, null: false
      t.string :avatar_url
      t.timestamps null: false
    end

    create_table :tokens do |t|
      t.belongs_to :user, index: true, null: false
      t.string :value, index: true, null: false
      t.timestamps null: false
    end
  end
end
