class FilmFilmer < ApplicationRecord
  belongs_to :film
  belongs_to :user

  validates :film_id, uniqueness: { scope: :user_id }

  after_commit :update_user_films_count

  private

  def update_user_films_count
    user&.update_films_count!
  end
end
