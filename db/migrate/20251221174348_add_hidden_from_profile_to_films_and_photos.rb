class AddHiddenFromProfileToFilmsAndPhotos < ActiveRecord::Migration[8.0]
  def change
    # Add table to track which users have hidden which films from their profile
    create_table :hidden_profile_films do |t|
      t.references :user, null: false, foreign_key: true
      t.references :film, null: false, foreign_key: true
      t.timestamps
    end
    add_index :hidden_profile_films, [:user_id, :film_id], unique: true

    # Add table to track which users have hidden which photos from their profile
    create_table :hidden_profile_photos do |t|
      t.references :user, null: false, foreign_key: true
      t.references :photo, null: false, foreign_key: true
      t.timestamps
    end
    add_index :hidden_profile_photos, [:user_id, :photo_id], unique: true

    # Add public/private field to playlists
    add_column :playlists, :is_public, :boolean, default: true, null: false
  end
end
