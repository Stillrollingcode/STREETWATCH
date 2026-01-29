class PhotoComment < ApplicationRecord
  include FriendlyIdentifiable

  belongs_to :user
  belongs_to :photo
  belongs_to :parent, class_name: 'PhotoComment', optional: true
  has_many :replies, class_name: 'PhotoComment', foreign_key: :parent_id, dependent: :destroy
  has_many :comment_likes, as: :likeable, dependent: :destroy
  has_many :likers, through: :comment_likes, source: :user

  validates :body, presence: true

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

  def self.friendly_id_prefix
    "PCM"
  end

  private

  def create_notifications
    # Notify the photo uploader when someone comments (unless it's their own comment)
    if photo.user != user && photo.user.preference&.notify_on_comment != false
      Notification.create(
        user: photo.user,
        actor: user,
        notifiable: photo,
        action: 'commented'
      )
    end

    # Notify the parent comment author when they receive a reply (unless it's their own reply)
    if parent.present? && parent.user != user && parent.user.preference&.notify_on_reply != false
      Notification.create(
        user: parent.user,
        actor: user,
        notifiable: photo,
        action: 'replied'
      )
    end
  end
end
