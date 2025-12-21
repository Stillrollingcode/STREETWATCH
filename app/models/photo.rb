class Photo < ApplicationRecord
  include FriendlyIdentifiable

  belongs_to :album
  belongs_to :user
  belongs_to :photographer_user, class_name: 'User', optional: true
  belongs_to :company_user, class_name: 'User', optional: true

  has_many :photo_riders, dependent: :destroy
  has_many :riders, through: :photo_riders, source: :user

  has_many :photo_approvals, dependent: :destroy
  has_many :photo_comments, dependent: :destroy
  has_many :favorites, as: :favoritable, dependent: :destroy

  has_one_attached :image
  has_one_attached :thumbnail

  validates :title, presence: true
  validates :image, presence: true, on: :create

  after_create :create_approval_requests

  scope :recent, -> { order(created_at: :desc) }
  scope :by_date, -> { order(date_taken: :desc) }
  scope :published, -> { joins(:image_attachment) }

  def photographer_name
    custom_photographer_name.presence || photographer_user&.name || user.name
  end

  def company_name
    company_user&.name
  end

  def all_riders
    (riders.map(&:name) + (custom_riders&.split(',')&.map(&:strip) || [])).compact
  end

  def all_approved?
    return true if photo_approvals.empty?
    photo_approvals.where(status: 'pending').none?
  end

  def has_rejected_approvals?
    photo_approvals.where(status: 'rejected').any?
  end

  def viewable_by?(user)
    return true if user == self.user  # Uploader can always view
    all_approved?                     # Public can only view if all approved
  end

  def self.friendly_id_prefix
    "PHO"
  end

  private

  def create_approval_requests
    # Create photographer approval if different from uploader
    if photographer_user_id.present? && photographer_user_id != user_id
      photo_approvals.create!(
        approver_id: photographer_user_id,
        approval_type: 'photographer',
        status: 'pending'
      )
    end

    # Create rider approvals
    riders.each do |rider|
      photo_approvals.create!(
        approver_id: rider.id,
        approval_type: 'rider',
        status: 'pending'
      )
    end

    # Create company approval
    if company_user_id.present?
      photo_approvals.create!(
        approver_id: company_user_id,
        approval_type: 'company',
        status: 'pending'
      )
    end
  rescue StandardError => e
    puts "Failed to create approval requests: #{e.message}"
  end
end
