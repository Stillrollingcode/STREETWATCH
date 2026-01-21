class AddReviewCacheColumnsToFilms < ActiveRecord::Migration[8.0]
  def change
    add_column :films, :reviews_count, :integer, default: 0, null: false
    add_column :films, :average_rating_cache, :decimal, precision: 3, scale: 1, default: 0.0, null: false

    # Add index for sorting by rating
    add_index :films, :average_rating_cache

    # Backfill existing data using Rails instead of raw SQL for compatibility
    reversible do |dir|
      dir.up do
        # Use ActiveRecord for database-agnostic backfill
        Film.reset_column_information
        Film.find_each do |film|
          reviews = FilmReview.where(film_id: film.id)
          count = reviews.count
          avg = count > 0 ? reviews.average(:rating).to_f.round(1) : 0.0
          film.update_columns(reviews_count: count, average_rating_cache: avg)
        end
      end
    end
  end
end
