class FilmReview < ApplicationRecord
  belongs_to :user
  belongs_to :film

  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :user_id, uniqueness: { scope: :film_id, message: "has already reviewed this film" }
  validates :comment, length: { maximum: 1000 }, allow_blank: true

  scope :recent, -> { order(created_at: :desc) }
end
