class FilmApproval < ApplicationRecord
  include FriendlyIdentifiable

  belongs_to :film
  belongs_to :approver, class_name: 'User'

  APPROVAL_TYPES = %w[filmer editor rider company].freeze
  STATUSES = %w[pending approved rejected].freeze

  validates :approval_type, presence: true, inclusion: { in: APPROVAL_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :approver_id, uniqueness: { scope: [:film_id, :approval_type] }

  scope :pending, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }

  # Callbacks
  after_update :check_and_notify_if_published, if: :saved_change_to_status?

  # Allow Ransack to search these associations in ActiveAdmin
  def self.ransackable_associations(auth_object = nil)
    ["approver", "film"]
  end

  # Friendly ID prefix for film approvals: FA####
  def self.friendly_id_prefix
    "FA"
  end

  # Allow Ransack to search these attributes in ActiveAdmin
  def self.ransackable_attributes(auth_object = nil)
    ["approval_type", "created_at", "film_id", "id", "rejection_reason", "status", "updated_at", "approver_id", "friendly_id"]
  end

  def approve!
    update!(status: 'approved', rejection_reason: nil)
  end

  def reject!(reason = nil)
    update!(status: 'rejected', rejection_reason: reason)
  end

  def reset!
    update!(status: 'pending', rejection_reason: nil)
  end

  private

  # Check if the film is now published after this approval status change
  def check_and_notify_if_published
    # Reload the film's pending_approvals to get the latest status
    film.reload

    # If the film is now published (no pending approvals), notify all associated users
    if film.published? && film.requires_approvals?
      notify_film_published
    end
  end

  # Notify all users associated with the film that it's now published
  def notify_film_published
    # Get all users who should be notified (film owner + all tagged users)
    users_to_notify = [film.user] + film.tagged_users
    users_to_notify = users_to_notify.compact.uniq

    # Create notifications for each user
    users_to_notify.each do |user|
      # Don't create duplicate notifications if one already exists
      next if Notification.exists?(
        user: user,
        notifiable: film,
        action: 'film_published'
      )

      Notification.create(
        user: user,
        actor: film.user, # The film owner is the actor
        notifiable: film,
        action: 'film_published'
      )
    end
  end
end
