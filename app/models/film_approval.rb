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
end
