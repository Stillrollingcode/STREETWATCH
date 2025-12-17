class Follow < ApplicationRecord
  belongs_to :follower, class_name: 'User'
  belongs_to :followed, class_name: 'User'

  validates :follower_id, presence: true
  validates :followed_id, presence: true
  validates :follower_id, uniqueness: { scope: :followed_id, message: "already following this user" }
  validate :cannot_follow_self

  after_create :create_default_notification_settings
  after_destroy :disable_notification_settings

  private

  def cannot_follow_self
    if follower_id == followed_id
      errors.add(:follower_id, "cannot follow yourself")
    end
  end

  # Automatically enable notification settings when following someone
  def create_default_notification_settings
    setting = follower.notification_settings_for(followed)

    # Enable all notifications by default when following
    setting.assign_attributes(
      notify_on_films: true,
      notify_on_photos: true,
      notify_on_articles: true,
      notify_on_featured_in_films: true,
      notify_on_featured_in_photos: true,
      notify_on_featured_in_articles: true
    )

    setting.save if setting.new_record? || setting.changed?
  end

  # Automatically disable notification settings when unfollowing someone
  def disable_notification_settings
    setting = follower.profile_notification_settings.find_by(target_user: followed)
    return unless setting

    # Disable all notifications when unfollowing
    setting.update(
      notify_on_films: false,
      notify_on_photos: false,
      notify_on_articles: false,
      notify_on_featured_in_films: false,
      notify_on_featured_in_photos: false,
      notify_on_featured_in_articles: false
    )
  end
end
