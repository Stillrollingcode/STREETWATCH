class CreateFilmReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :film_reviews do |t|
      t.references :user, null: false, foreign_key: true
      t.references :film, null: false, foreign_key: true
      t.integer :rating, null: false
      t.text :comment

      t.timestamps
    end

    # Add index to prevent duplicate reviews from same user on same film
    add_index :film_reviews, [:user_id, :film_id], unique: true
  end
end
