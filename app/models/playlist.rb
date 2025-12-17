class Playlist < ApplicationRecord
  include FriendlyIdentifiable

  belongs_to :user
  has_many :playlist_films, dependent: :destroy
  has_many :films, through: :playlist_films

  validates :name, presence: true, length: { minimum: 1, maximum: 100 }

  scope :recent, -> { order(updated_at: :desc) }

  # Friendly ID prefix for playlists: PL####
  def self.friendly_id_prefix
    "PL"
  end

  # Ransack configuration for ActiveAdmin filtering
  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "description", "id", "name", "updated_at", "user_id", "friendly_id"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["user", "films", "playlist_films"]
  end
end
