class AddFeaturedInNotificationsToProfileNotificationSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :profile_notification_settings, :notify_on_featured_in_films, :boolean, default: false
    add_column :profile_notification_settings, :notify_on_featured_in_photos, :boolean, default: false
    add_column :profile_notification_settings, :notify_on_featured_in_articles, :boolean, default: false
  end
end
