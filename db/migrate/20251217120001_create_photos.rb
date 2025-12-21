class CreatePhotos < ActiveRecord::Migration[8.0]
  def change
    create_table :photos do |t|
      t.string :title, null: false
      t.text :description
      t.date :date_taken
      t.references :album, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :photographer_user_id
      t.integer :company_user_id
      t.string :custom_photographer_name
      t.text :custom_riders
      t.string :friendly_id

      t.timestamps
    end

    add_index :photos, :friendly_id, unique: true
    add_index :photos, :photographer_user_id
    add_index :photos, :company_user_id
    add_index :photos, :date_taken
    add_foreign_key :photos, :users, column: :photographer_user_id
    add_foreign_key :photos, :users, column: :company_user_id
  end
end
