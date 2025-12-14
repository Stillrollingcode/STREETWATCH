class FilmRider < ApplicationRecord
  belongs_to :film
  belongs_to :user

  validates :film_id, uniqueness: { scope: :user_id }
end
