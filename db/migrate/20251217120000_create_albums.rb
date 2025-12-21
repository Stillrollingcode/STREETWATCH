class CreateAlbums < ActiveRecord::Migration[8.0]
  def change
    create_table :albums do |t|
      t.string :title, null: false
      t.text :description
      t.date :date
      t.references :user, null: false, foreign_key: true
      t.string :friendly_id

      t.timestamps
    end

    add_index :albums, :friendly_id, unique: true
    add_index :albums, :date
  end
end
