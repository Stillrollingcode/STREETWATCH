class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :actor, class_name: 'User'
  belongs_to :notifiable, polymorphic: true

  validates :action, presence: true
  validates :user_id, presence: true
  validates :actor_id, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  # Mark notification as read
  def mark_as_read!
    update(read_at: Time.current) unless read?
  end

  # Check if notification is read
  def read?
    read_at.present?
  end

  # Check if notification is unread
  def unread?
    !read?
  end

  # Generate notification title based on action
  def title
    case action
    when 'followed'
      "New Follower"
    when 'commented'
      "New Comment"
    when 'mentioned'
      "Mentioned"
    when 'favorited'
      "Film Favorited"
    when 'posted_film'
      "New Film"
    when 'posted_photo'
      "New Photo"
    when 'posted_article'
      "New Article"
    else
      "Notification"
    end
  end

  # Generate notification message based on action
  def message
    case action
    when 'followed'
      "#{actor.username} started following you"
    when 'commented'
      "#{actor.username} commented on your film"
    when 'mentioned'
      "#{actor.username} mentioned you in a comment"
    when 'favorited'
      "#{actor.username} favorited your film"
    when 'posted_film'
      "#{actor.username} posted a new film"
    when 'posted_photo'
      "#{actor.username} posted a new photo"
    when 'posted_article'
      "#{actor.username} posted a new article"
    else
      "New notification from #{actor.username}"
    end
  end

  # Generate target path based on notification type
  def target_path
    case action
    when 'followed'
      "/users/#{actor.id}"
    when 'commented', 'mentioned', 'favorited'
      if notifiable_type == 'Film' && notifiable
        "/films/#{notifiable.id}"
      else
        "/"
      end
    when 'posted_film', 'posted_photo', 'posted_article'
      if notifiable_type == 'Film' && notifiable
        "/films/#{notifiable.id}"
      else
        "/users/#{actor.id}"
      end
    else
      "/users/#{actor.id}"
    end
  end
end
