class PhotoApproval < ApplicationRecord
  include FriendlyIdentifiable

  belongs_to :photo
  belongs_to :approver, class_name: 'User'

  APPROVAL_TYPES = %w[photographer rider company].freeze
  STATUSES = %w[pending approved rejected].freeze

  validates :approval_type, presence: true, inclusion: { in: APPROVAL_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :approver_id, uniqueness: { scope: [:photo_id, :approval_type] }

  scope :pending, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }

  # Allow Ransack to search these associations in ActiveAdmin
  def self.ransackable_associations(auth_object = nil)
    ["approver", "photo"]
  end

  # Allow Ransack to search these attributes in ActiveAdmin
  def self.ransackable_attributes(auth_object = nil)
    ["approval_type", "created_at", "photo_id", "id", "rejection_reason", "status", "updated_at", "approver_id", "friendly_id"]
  end

  # Friendly ID prefix for photo approvals: PAP####
  def self.friendly_id_prefix
    "PAP"
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
