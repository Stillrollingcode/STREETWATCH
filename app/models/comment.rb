class Comment < ApplicationRecord
  include FriendlyIdentifiable

  belongs_to :user
  belongs_to :film
  belongs_to :parent, class_name: 'Comment', optional: true
  has_many :replies, class_name: 'Comment', foreign_key: 'parent_id', dependent: :destroy
  has_many :comment_likes, as: :likeable, dependent: :destroy
  has_many :likers, through: :comment_likes, source: :user

  validates :body, presence: true, length: { minimum: 1, maximum: 5000 }

  after_create_commit :create_notifications

  scope :recent, -> { order(created_at: :desc) }
  scope :top_level, -> { where(parent_id: nil) }

  def liked_by?(user)
    return false unless user
    comment_likes.exists?(user_id: user.id)
  end

  def likes_count
    comment_likes.count
  end

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

  private

  def create_notifications
    # Notify the film uploader when someone comments (unless it's their own comment)
    if film.user != user && film.user.preference&.notify_on_comment != false
      Notification.create(
        user: film.user,
        actor: user,
        notifiable: film,
        action: 'commented'
      )
    end

    # Notify the parent comment author when they receive a reply (unless it's their own reply)
    if parent.present? && parent.user != user && parent.user.preference&.notify_on_reply != false
      Notification.create(
        user: parent.user,
        actor: user,
        notifiable: film,
        action: 'replied'
      )
    end
  end
end
