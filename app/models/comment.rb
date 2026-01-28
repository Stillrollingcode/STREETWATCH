class Comment < ApplicationRecord
  include FriendlyIdentifiable

  belongs_to :user
  belongs_to :film
  belongs_to :parent, class_name: 'Comment', optional: true
  has_many :replies, class_name: 'Comment', foreign_key: 'parent_id', dependent: :destroy
  has_many :comment_likes, as: :likeable, dependent: :destroy
  has_many :likers, through: :comment_likes, source: :user

  validates :body, presence: true, length: { minimum: 1, maximum: 5000 }

  def liked_by?(user)
    return false unless user
    comment_likes.exists?(user_id: user.id)
  end

  def likes_count
    comment_likes.count
  end

  scope :recent, -> { order(created_at: :desc) }
  scope :top_level, -> { where(parent_id: nil) }

  # Friendly ID prefix for comments: C####
  def self.friendly_id_prefix
    "C"
  end

  # Ransack configuration for ActiveAdmin filtering
  def self.ransackable_attributes(auth_object = nil)
    ["body", "created_at", "film_id", "id", "parent_id", "updated_at", "user_id", "friendly_id"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["user", "film", "parent", "replies"]
  end
end
