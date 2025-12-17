class CreateProfileNotificationSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :profile_notification_settings do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :target_user, null: false, foreign_key: { to_table: :users }, index: false

      # Content type notifications
      t.boolean :notify_on_films, default: false
      t.boolean :notify_on_photos, default: false
      t.boolean :notify_on_articles, default: false

      # Mute option
      t.boolean :muted, default: false

      t.timestamps
    end

    # Composite index to ensure one setting per user-target_user pair
    add_index :profile_notification_settings, [:user_id, :target_user_id], unique: true, name: 'index_profile_notifications_on_user_and_target'
    # Index for finding all users watching a target user
    add_index :profile_notification_settings, :target_user_id
  end
end
