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
    when 'sponsorship_requested'
      "Sponsorship Request"
    when 'sponsorship_approved'
      "Sponsorship Approved"
    when 'sponsorship_rejected'
      "Sponsorship Rejected"
    when 'tag_requested'
      "Tag Request"
    when 'tag_request_approved'
      "Tag Request Approved"
    when 'tag_request_denied'
      "Tag Request Denied"
    when 'tag_approved'
      "Tag Approved"
    when 'tag_rejected'
      "Tag Rejected"
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
    when 'sponsorship_requested'
      "#{actor.username} requested you as a sponsor"
    when 'sponsorship_approved'
      "#{actor.username} approved your sponsorship request"
    when 'sponsorship_rejected'
      "#{actor.username} rejected your sponsorship request"
    when 'tag_requested'
      if notifiable_type == 'TagRequest' && notifiable
        "#{actor.username} requested to be tagged as #{notifiable.role} in your film"
      else
        "#{actor.username} requested to be tagged in your film"
      end
    when 'tag_request_approved'
      if notifiable_type == 'TagRequest' && notifiable
        "Your request to be tagged as #{notifiable.role} was approved"
      else
        "Your tag request was approved"
      end
    when 'tag_request_denied'
      if notifiable_type == 'TagRequest' && notifiable
        "Your request to be tagged as #{notifiable.role} was denied"
      else
        "Your tag request was denied"
      end
    when 'tag_approved'
      if notifiable_type == 'FilmApproval'
        "#{actor.username} approved your tag on their film"
      elsif notifiable_type == 'PhotoApproval'
        "#{actor.username} approved your tag on their photo"
      else
        "#{actor.username} approved your tag"
      end
    when 'tag_rejected'
      if notifiable_type == 'FilmApproval'
        "#{actor.username} rejected your tag on their film"
      elsif notifiable_type == 'PhotoApproval'
        "#{actor.username} rejected your tag on their photo"
      else
        "#{actor.username} rejected your tag"
      end
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
    when 'sponsorship_requested'
      "/sponsor_approvals"
    when 'sponsorship_approved', 'sponsorship_rejected'
      "/users/#{actor.id}"
    when 'tag_requested', 'tag_request_approved', 'tag_request_denied'
      if notifiable_type == 'TagRequest' && notifiable.respond_to?(:film) && notifiable.film
        "/films/#{notifiable.film.id}"
      else
        "/"
      end
    when 'tag_approved', 'tag_rejected'
      if notifiable_type == 'FilmApproval' && notifiable.respond_to?(:film) && notifiable.film
        "/films/#{notifiable.film.id}"
      elsif notifiable_type == 'PhotoApproval' && notifiable.respond_to?(:photo) && notifiable.photo
        "/photos/#{notifiable.photo.id}"
      else
        "/users/#{actor.id}"
      end
    else
      "/users/#{actor.id}"
    end
  end
end
