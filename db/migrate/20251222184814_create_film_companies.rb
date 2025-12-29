class CreateFilmCompanies < ActiveRecord::Migration[8.0]
  def change
    create_table :film_companies do |t|
      t.references :film, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :film_companies, [:film_id, :user_id], unique: true
  end
end
