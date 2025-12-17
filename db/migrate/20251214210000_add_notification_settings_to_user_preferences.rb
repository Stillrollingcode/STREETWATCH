class AddNotificationSettingsToUserPreferences < ActiveRecord::Migration[8.0]
  def change
    add_column :user_preferences, :email_notifications_enabled, :boolean, default: true
    add_column :user_preferences, :notify_on_new_follower, :boolean, default: true
    add_column :user_preferences, :notify_on_comment, :boolean, default: true
    add_column :user_preferences, :notify_on_mention, :boolean, default: true
    add_column :user_preferences, :notify_on_favorite, :boolean, default: true
  end
end
