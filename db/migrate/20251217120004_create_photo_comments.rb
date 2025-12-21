class CreatePhotoComments < ActiveRecord::Migration[8.0]
  def change
    create_table :photo_comments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :photo, null: false, foreign_key: true
      t.text :body, null: false
      t.integer :parent_id
      t.string :friendly_id

      t.timestamps
    end

    add_index :photo_comments, [:photo_id, :created_at]
    add_index :photo_comments, :parent_id
    add_index :photo_comments, :friendly_id, unique: true
    add_foreign_key :photo_comments, :photo_comments, column: :parent_id
  end
end
