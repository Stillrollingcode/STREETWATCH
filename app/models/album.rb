class Album < ApplicationRecord
  include FriendlyIdentifiable

  belongs_to :user
  has_many :photos, dependent: :destroy

  validates :title, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_date, -> { order(date: :desc) }

  def self.friendly_id_prefix
    "ALB"
  end
end
