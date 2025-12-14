class CreatePlaylists < ActiveRecord::Migration[8.0]
  def change
    create_table :playlists do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description

      t.timestamps
    end

    add_index :playlists, [:user_id, :name]
  end
end
