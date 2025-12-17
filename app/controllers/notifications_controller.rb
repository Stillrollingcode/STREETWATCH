class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def mark_as_read
    # Mark all non-tagging notifications as read
    # Tagging notifications are film approvals, not regular notifications
    current_user.notifications.unread.update_all(read_at: Time.current)

    head :ok
  end
end
