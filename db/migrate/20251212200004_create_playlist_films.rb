class CreatePlaylistFilms < ActiveRecord::Migration[8.0]
  def change
    create_table :playlist_films do |t|
      t.references :playlist, null: false, foreign_key: true
      t.references :film, null: false, foreign_key: true
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :playlist_films, [:playlist_id, :film_id], unique: true
    add_index :playlist_films, [:playlist_id, :position]
  end
end
