class Playlist < ApplicationRecord
  belongs_to :user
  has_many :playlist_films, dependent: :destroy
  has_many :films, through: :playlist_films

  validates :name, presence: true, length: { minimum: 1, maximum: 100 }

  scope :recent, -> { order(updated_at: :desc) }
end
