class AddFilmTypeToFilms < ActiveRecord::Migration[8.0]
  def change
    add_column :films, :film_type, :string, default: "full_length"
    add_column :films, :parent_film_title, :string

    add_index :films, :film_type
  end
end
