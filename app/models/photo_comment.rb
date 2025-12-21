class PhotoComment < ApplicationRecord
  include FriendlyIdentifiable

  belongs_to :user
  belongs_to :photo
  belongs_to :parent, class_name: 'PhotoComment', optional: true
  has_many :replies, class_name: 'PhotoComment', foreign_key: :parent_id, dependent: :destroy

  validates :body, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :top_level, -> { where(parent_id: nil) }

  def self.friendly_id_prefix
    "PCM"
  end
end
