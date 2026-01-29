class AddNotifyOnReplyToUserPreferences < ActiveRecord::Migration[8.0]
  def change
    add_column :user_preferences, :notify_on_reply, :boolean, default: true
  end
end
