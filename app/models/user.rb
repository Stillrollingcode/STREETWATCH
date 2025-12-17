class User < ApplicationRecord
  include FriendlyIdentifiable

  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  enum :profile_type, { individual: 'individual', company: 'company' }, default: :individual

  has_one_attached :avatar
  has_many :film_riders, dependent: :destroy
  has_many :rider_films, through: :film_riders, source: :film
  has_many :filmed_films, class_name: 'Film', foreign_key: 'filmer_user_id'
  has_many :edited_films, class_name: 'Film', foreign_key: 'editor_user_id'
  has_many :company_films, class_name: 'Film', foreign_key: 'company_user_id'

  # Film approvals
  has_many :film_approvals, foreign_key: 'approver_id', dependent: :destroy

  # Favorites, comments, and playlists
  has_many :favorites, dependent: :destroy
  has_many :favorited_films, through: :favorites, source: :film
  has_many :comments, dependent: :destroy
  has_many :playlists, dependent: :destroy
  has_one :preference, class_name: 'UserPreference', dependent: :destroy

  # Follows (followers and following)
  has_many :active_follows, class_name: 'Follow', foreign_key: 'follower_id', dependent: :destroy
  has_many :passive_follows, class_name: 'Follow', foreign_key: 'followed_id', dependent: :destroy
  has_many :following, through: :active_follows, source: :followed
  has_many :followers, through: :passive_follows, source: :follower

  # Profile notification settings
  has_many :profile_notification_settings, dependent: :destroy
  has_many :watching_notifications_for, through: :profile_notification_settings, source: :target_user

  # Notifications
  has_many :notifications, dependent: :destroy
  has_many :sent_notifications, class_name: 'Notification', foreign_key: 'actor_id', dependent: :destroy

  validates :username, presence: true, uniqueness: { case_sensitive: false }, format: { with: /\A[a-zA-Z0-9_.]+\z/, message: "letters, numbers, underscore, and dot only" }
  validates :name, presence: true

  # Get all films associated with this user (as rider, filmer, editor, or company)
  def all_films
    Film.where(id: (rider_films.pluck(:id) + filmed_films.pluck(:id) + edited_films.pluck(:id) + company_films.pluck(:id)).uniq)
        .includes(thumbnail_attachment: :blob)
        .recent
  end

  # Get roles for a specific film
  def film_roles(film)
    roles = []
    roles << 'Filmer' if film.filmer_user_id == id
    roles << 'Editor' if film.editor_user_id == id
    roles << 'Rider' if film.riders.include?(self)
    roles << 'Company' if film.company_user_id == id
    roles
  end

  # Follow another user
  def follow(other_user)
    return false if self == other_user
    active_follows.create(followed: other_user)
  end

  # Unfollow a user
  def unfollow(other_user)
    active_follows.find_by(followed: other_user)&.destroy
  end

  # Check if following a user
  def following?(other_user)
    following.include?(other_user)
  end

  # Get or create notification settings for a target user
  def notification_settings_for(target_user)
    profile_notification_settings.find_or_initialize_by(target_user: target_user)
  end

  # Check if user has muted another user
  def muted?(other_user)
    setting = profile_notification_settings.find_by(target_user: other_user)
    setting&.muted || false
  end

  # Mute a user
  def mute(other_user)
    return false if self == other_user
    setting = notification_settings_for(other_user)
    setting.muted = true
    setting.save
  end

  # Unmute a user
  def unmute(other_user)
    setting = profile_notification_settings.find_by(target_user: other_user)
    return false unless setting
    setting.muted = false
    setting.save
  end

  before_validation :normalize_username
  before_create :generate_claim_token, if: :admin_created?
  before_create :skip_confirmation_for_admin_created, if: :admin_created?

  # Admin-created profile methods
  def generate_claim_token
    self.claim_token = SecureRandom.urlsafe_base64(32)
  end

  def skip_confirmation_for_admin_created
    skip_confirmation!
  end

  def claimable?
    admin_created? && claimed_at.nil?
  end

  def claimed?
    claimed_at.present?
  end

  # Create or locate a user from an OmniAuth auth hash.
  def self.from_omniauth(auth)
    email = auth.info.email
    user = find_or_initialize_by(email: email)
    email_name = auth.info.email.to_s.split("@").first
    user.name ||= auth.info.name.presence || email_name.presence || "new user"
    user.username ||= generate_available_username(auth.info.nickname.presence || email_name || auth.info.name)
    user.password ||= Devise.friendly_token[0, 20]
    # Auto-confirm OAuth users since their email is verified by the provider
    user.skip_confirmation! if user.new_record?
    user.save
    user
  end

  # Friendly ID prefix for users: U####
  def self.friendly_id_prefix
    "U"
  end

  # Ransack configuration for ActiveAdmin filtering
  def self.ransackable_attributes(auth_object = nil)
    ["admin_created", "bio", "claimed_at", "created_at", "email", "id", "name",
     "profile_type", "sponsor_requests", "subscription_active", "updated_at", "username", "friendly_id"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["rider_films", "filmed_films", "edited_films", "favorites", "comments", "playlists"]
  end

  private

  def normalize_username
    self.username = username&.strip&.downcase
  end

  def self.generate_available_username(base)
    base_username = base.to_s.downcase.gsub(/[^a-z0-9_.]/, "_")
    base_username = base_username.gsub(/_+/, "_").gsub(/\A_+|_+\z/, "")
    base_username = "user" if base_username.blank?

    candidate = base_username
    suffix = 1
    while where("LOWER(username) = ?", candidate.downcase).exists?
      candidate = "#{base_username}_#{suffix}"
      suffix += 1
    end

    candidate
  end
end
