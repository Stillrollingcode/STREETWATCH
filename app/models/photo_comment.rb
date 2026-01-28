class PhotoComment < ApplicationRecord
  include FriendlyIdentifiable

  belongs_to :user
  belongs_to :photo
  belongs_to :parent, class_name: 'PhotoComment', optional: true
  has_many :replies, class_name: 'PhotoComment', foreign_key: :parent_id, dependent: :destroy
  has_many :comment_likes, as: :likeable, dependent: :destroy
  has_many :likers, through: :comment_likes, source: :user

  validates :body, presence: true

  def liked_by?(user)
    return false unless user
    comment_likes.exists?(user_id: user.id)
  end

  def likes_count
    comment_likes.count
  end

  scope :recent, -> { order(created_at: :desc) }
  scope :top_level, -> { where(parent_id: nil) }

  def self.friendly_id_prefix
    "PCM"
  end
end
