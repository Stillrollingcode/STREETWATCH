class HiddenProfileFilm < ApplicationRecord
  belongs_to :user
  belongs_to :film

  validates :user_id, uniqueness: { scope: :film_id }
end
