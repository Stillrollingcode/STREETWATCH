class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def mark_as_read
    # Mark all non-tagging notifications as read
    # Tagging notifications are film approvals, not regular notifications
    current_user.notifications.unread.update_all(read_at: Time.current)

    head :ok
  end

  def menu
    pending_approvals_count = current_user.film_approvals.pending.count
    unread_notifications_count = current_user.notifications.unread.count
    total_activity_count = pending_approvals_count + unread_notifications_count

    pending_approvals = current_user.film_approvals.pending.includes(:film).limit(5)
    unread_notifications = current_user.notifications.unread
                                       .includes(:actor, :notifiable)
                                       .order(created_at: :desc)
                                       .limit(5)
    all_notifications = current_user.notifications
                                    .includes(:actor, :notifiable)
                                    .order(created_at: :desc)
                                    .limit(20)

    unread_grouped = view_context.group_notifications(unread_notifications)
    all_grouped = view_context.group_notifications(all_notifications)
    has_more_notifications = current_user.notifications.where.not(read_at: nil).exists? ||
                             current_user.notifications.count > 5

    render partial: "shared/activity_menu", locals: {
      pending_approvals_count: pending_approvals_count,
      unread_notifications_count: unread_notifications_count,
      total_activity_count: total_activity_count,
      pending_approvals: pending_approvals,
      unread_grouped: unread_grouped,
      all_grouped: all_grouped,
      has_more_notifications: has_more_notifications
    }
  end

  def counts
    pending_approvals_count = current_user.film_approvals.pending.count
    unread_notifications_count = current_user.notifications.unread.count
    total_activity_count = pending_approvals_count + unread_notifications_count

    render json: {
      pending_approvals_count: pending_approvals_count,
      unread_notifications_count: unread_notifications_count,
      total_activity_count: total_activity_count
    }
  end
end
