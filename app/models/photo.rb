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

  # Hidden from profile associations
  has_many :hidden_profile_photos, dependent: :destroy
  has_many :hidden_by_users, through: :hidden_profile_photos, source: :user

  has_one_attached :image
  has_one_attached :thumbnail

  validates :title, presence: true
  validates :image, presence: true, on: :create

  after_create :create_approval_requests

  scope :recent, -> { order(created_at: :desc) }
  scope :by_date, -> { order(date_taken: :desc) }
  scope :published, -> {
    joins(:image_attachment)
    .where(id: Photo.select(:id).left_joins(:photo_approvals).group(:id).having('COUNT(CASE WHEN photo_approvals.status = ? THEN 1 END) = 0', 'pending'))
  }

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

  def tagged_users
    users = []
    users << photographer_user if photographer_user.present?
    users << company_user if company_user.present?
    users += riders.to_a
    users.uniq
  end

  def self.friendly_id_prefix
    "PHO"
  end

  def self.ransackable_attributes(auth_object = nil)
    ["album_id", "company_user_id", "created_at", "custom_photographer_name", "custom_riders", "date_taken", "description", "friendly_id", "id", "photographer_user_id", "title", "updated_at", "user_id"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["album", "company_user", "photo_approvals", "photo_comments", "photo_riders", "photographer_user", "riders", "user"]
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

    # Create rider approvals (auto-approve if user is tagging themselves)
    riders.each do |rider|
      status = (rider.id == user_id) ? 'approved' : 'pending'
      photo_approvals.create!(
        approver_id: rider.id,
        approval_type: 'rider',
        status: status
      )
    end

    # Create company approval (auto-approve if user is tagging themselves)
    if company_user_id.present?
      status = (company_user_id == user_id) ? 'approved' : 'pending'
      photo_approvals.create!(
        approver_id: company_user_id,
        approval_type: 'company',
        status: status
      )
    end
  rescue StandardError => e
    puts "Failed to create approval requests: #{e.message}"
  end
end
