class ProfileNotificationSetting < ApplicationRecord
  belongs_to :user
  belongs_to :target_user, class_name: 'User'

  validates :user_id, uniqueness: { scope: :target_user_id, message: "already has notification settings for this profile" }
  validate :cannot_set_notifications_for_self

  # Set defaults from user's global preferences after initialization
  after_initialize :set_defaults_from_preferences, if: :new_record?

  # Check if any notifications are enabled
  def any_notifications_enabled?
    notify_on_films || notify_on_photos || notify_on_articles ||
    notify_on_featured_in_films || notify_on_featured_in_photos || notify_on_featured_in_articles
  end

  # Check if all notifications are enabled
  def all_notifications_enabled?
    notify_on_films && notify_on_photos && notify_on_articles &&
    notify_on_featured_in_films && notify_on_featured_in_photos && notify_on_featured_in_articles
  end

  # Enable all content notifications
  def enable_all!
    update(
      notify_on_films: true,
      notify_on_photos: true,
      notify_on_articles: true,
      notify_on_featured_in_films: true,
      notify_on_featured_in_photos: true,
      notify_on_featured_in_articles: true
    )
  end

  # Disable all content notifications
  def disable_all!
    update(
      notify_on_films: false,
      notify_on_photos: false,
      notify_on_articles: false,
      notify_on_featured_in_films: false,
      notify_on_featured_in_photos: false,
      notify_on_featured_in_articles: false
    )
  end

  private

  def cannot_set_notifications_for_self
    if user_id == target_user_id
      errors.add(:target_user_id, "cannot set notification settings for yourself")
    end
  end

  # Set defaults from user's global notification preferences
  def set_defaults_from_preferences
    return unless user&.preference

    # Only set if values haven't been explicitly set
    self.notify_on_films = true if notify_on_films.nil?
    self.notify_on_photos = true if notify_on_photos.nil?
    self.notify_on_articles = true if notify_on_articles.nil?
  end
end
