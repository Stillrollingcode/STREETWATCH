class CreateFilms < ActiveRecord::Migration[8.0]
  def change
    create_table :films do |t|
      t.string :title, null: false
      t.text :description
      t.date :release_date
      t.string :filmer
      t.string :editor
      t.string :company
      t.integer :runtime
      t.text :music_featured

      t.timestamps
    end

    add_index :films, :title
    add_index :films, :release_date
  end
end
