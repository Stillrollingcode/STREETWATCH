class PlaylistFilm < ApplicationRecord
  belongs_to :playlist
  belongs_to :film

  validates :film_id, uniqueness: { scope: :playlist_id }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(position: :asc) }
end
