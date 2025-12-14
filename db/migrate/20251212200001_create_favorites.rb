class CreateFavorites < ActiveRecord::Migration[8.0]
  def change
    create_table :favorites do |t|
      t.references :user, null: false, foreign_key: true
      t.references :film, null: false, foreign_key: true

      t.timestamps
    end

    add_index :favorites, [:user_id, :film_id], unique: true
  end
end
