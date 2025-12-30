class AddCreatedAtIndexToFilms < ActiveRecord::Migration[8.0]
  def change
    add_index :films, :created_at
  end
end
