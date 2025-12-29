class SponsorApproval < ApplicationRecord
  include FriendlyIdentifiable

  belongs_to :user
  belongs_to :sponsor, class_name: 'User'

  STATUSES = %w[pending approved rejected].freeze

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :sponsor_id, uniqueness: { scope: :user_id }

  scope :pending, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }

  # Allow Ransack to search these associations in ActiveAdmin
  def self.ransackable_associations(auth_object = nil)
    ["user", "sponsor"]
  end

  # Friendly ID prefix for sponsor approvals: SA####
  def self.friendly_id_prefix
    "SA"
  end

  # Allow Ransack to search these attributes in ActiveAdmin
  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "id", "rejection_reason", "sponsor_id", "status", "updated_at", "user_id", "friendly_id"]
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
