class CreatePhotoRiders < ActiveRecord::Migration[8.0]
  def change
    create_table :photo_riders do |t|
      t.references :photo, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :photo_riders, [:photo_id, :user_id], unique: true
  end
end
