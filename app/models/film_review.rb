class FilmReview < ApplicationRecord
  belongs_to :user
  belongs_to :film, counter_cache: :reviews_count

  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :user_id, uniqueness: { scope: :film_id, message: "has already reviewed this film" }
  validates :comment, length: { maximum: 1000 }, allow_blank: true

  scope :recent, -> { order(created_at: :desc) }

  after_save :update_film_average_rating
  after_destroy :update_film_average_rating

  private

  def update_film_average_rating
    avg = film.film_reviews.average(:rating).to_f.round(1)
    film.update_column(:average_rating_cache, avg)
  end
end
