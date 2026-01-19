class User < ApplicationRecord
  include FriendlyIdentifiable
  include Searchable

  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  enum :profile_type, { individual: 'individual', company: 'company', crew: 'crew' }, default: :individual

  # Check if user is a company-type account (company or crew)
  def company_type?
    company? || crew?
  end

  has_one_attached :avatar
  has_many :film_riders, dependent: :destroy
  has_many :rider_films, through: :film_riders, source: :film

  # Multi-select filmer associations
  has_many :film_filmers, dependent: :destroy
  has_many :filmer_films, through: :film_filmers, source: :film

  # Multi-select company associations
  has_many :film_companies, dependent: :destroy
  has_many :multi_company_films, through: :film_companies, source: :film

  # Legacy single associations (backwards compatibility)
  has_many :filmed_films, class_name: 'Film', foreign_key: 'filmer_user_id'
  has_many :edited_films, class_name: 'Film', foreign_key: 'editor_user_id'
  has_many :company_films, class_name: 'Film', foreign_key: 'company_user_id'

  # Film approvals
  has_many :film_approvals, foreign_key: 'approver_id', dependent: :destroy

  # Tag requests (users requesting to be tagged in films)
  has_many :tag_requests, foreign_key: 'requester_id', dependent: :destroy

  # Photos and albums
  has_many :albums, dependent: :destroy
  has_many :photos, dependent: :destroy
  has_many :photographed_photos, class_name: 'Photo', foreign_key: :photographer_user_id
  has_many :photo_company_photos, class_name: 'Photo', foreign_key: :company_user_id
  has_many :photo_riders, dependent: :destroy
  has_many :photos_featured_in, through: :photo_riders, source: :photo
  has_many :photo_approvals, foreign_key: :approver_id, dependent: :destroy
  has_many :photo_comments, dependent: :destroy

  # Favorites, comments, and playlists
  has_many :favorites, dependent: :destroy
  has_many :favorited_films, through: :favorites, source: :film
  has_many :comments, dependent: :destroy
  has_many :playlists, dependent: :destroy
  has_one :preference, class_name: 'UserPreference', dependent: :destroy
  accepts_nested_attributes_for :preference, update_only: true

  # Follows (followers and following)
  has_many :active_follows, class_name: 'Follow', foreign_key: 'follower_id', dependent: :destroy
  has_many :passive_follows, class_name: 'Follow', foreign_key: 'followed_id', dependent: :destroy
  has_many :following, through: :active_follows, source: :followed
  has_many :followers, through: :passive_follows, source: :follower

  # Profile notification settings
  has_many :profile_notification_settings, dependent: :destroy
  has_many :watched_by_notification_settings, class_name: 'ProfileNotificationSetting', foreign_key: :target_user_id, dependent: :destroy
  has_many :watching_notifications_for, through: :profile_notification_settings, source: :target_user

  # Notifications
  has_many :notifications, dependent: :destroy
  has_many :sent_notifications, class_name: 'Notification', foreign_key: 'actor_id', dependent: :destroy

  # Sponsor approvals
  has_many :sponsor_approvals, dependent: :destroy
  has_many :sponsored_by_approvals, class_name: 'SponsorApproval', foreign_key: 'sponsor_id', dependent: :destroy
  has_many :approved_sponsors, -> { where(sponsor_approvals: { status: 'approved' }) }, through: :sponsor_approvals, source: :sponsor
  has_many :sponsored_users, -> { where(sponsor_approvals: { status: 'approved' }) }, through: :sponsored_by_approvals, source: :user

  # Hidden content from profile
  has_many :hidden_profile_films, dependent: :destroy
  has_many :hidden_films, through: :hidden_profile_films, source: :film
  has_many :hidden_profile_photos, dependent: :destroy
  has_many :hidden_photos, through: :hidden_profile_photos, source: :photo

  validates :username, presence: true, uniqueness: { case_sensitive: false }, format: { with: /\A[a-zA-Z0-9_.]+\z/, message: "letters, numbers, underscore, and dot only" }
  validates :name, presence: true

  # Get all films associated with this user (as rider, filmer, editor, or company)
  # Always filters out hidden films - hidden films only appear in the "Hidden" tab
  # Optimized: Uses a single SQL query with UNION instead of 6+ separate queries
  def all_films(viewing_user: nil)
    # Build a single query to get all film IDs where user is associated
    # This replaces 6 separate pluck queries with one efficient UNION
    film_ids_sql = <<~SQL
      SELECT DISTINCT film_id FROM (
        SELECT film_id FROM film_riders WHERE user_id = :user_id
        UNION
        SELECT film_id FROM film_filmers WHERE user_id = :user_id
        UNION
        SELECT id AS film_id FROM films WHERE filmer_user_id = :user_id
        UNION
        SELECT id AS film_id FROM films WHERE editor_user_id = :user_id
        UNION
        SELECT film_id FROM film_companies WHERE user_id = :user_id
        UNION
        SELECT id AS film_id FROM films WHERE company_user_id = :user_id
      ) AS all_film_ids
      WHERE film_id NOT IN (
        SELECT film_id FROM hidden_profile_films WHERE user_id = :user_id
      )
    SQL

    film_ids = Film.connection.select_values(
      Film.sanitize_sql([film_ids_sql, { user_id: id }])
    )

    Film.published
        .where(id: film_ids)
        .includes(thumbnail_attachment: :blob)
        .recent
  end

  # Get films hidden from profile (only for own profile)
  def hidden_films_from_profile
    Film.published
        .joins("INNER JOIN hidden_profile_films ON hidden_profile_films.film_id = films.id")
        .where(hidden_profile_films: { user_id: id })
        .includes(thumbnail_attachment: :blob)
        .recent
  end

  # Get roles for a specific film
  def film_roles(film)
    roles = []
    # Check both multi-select and legacy single associations for filmers
    roles << 'Filmer' if film.filmers.include?(self) || film.filmer_user_id == id
    roles << 'Editor' if film.editor_user_id == id
    roles << 'Rider' if film.riders.include?(self)
    # Check both multi-select and legacy single associations for companies
    roles << 'Company' if film.companies.include?(self) || film.company_user_id == id
    roles
  end

  # Get all photos associated with this user (as rider, photographer, or company)
  # Always filters out hidden photos - hidden photos only appear in the "Hidden" tab
  # Optimized: Uses a single SQL query with UNION instead of 3+ separate queries
  def all_photos(viewing_user: nil)
    # Build a single query to get all photo IDs where user is associated
    photo_ids_sql = <<~SQL
      SELECT DISTINCT photo_id FROM (
        SELECT photo_id FROM photo_riders WHERE user_id = :user_id
        UNION
        SELECT id AS photo_id FROM photos WHERE photographer_user_id = :user_id
        UNION
        SELECT id AS photo_id FROM photos WHERE company_user_id = :user_id
      ) AS all_photo_ids
      WHERE photo_id NOT IN (
        SELECT photo_id FROM hidden_profile_photos WHERE user_id = :user_id
      )
    SQL

    photo_ids = Photo.connection.select_values(
      Photo.sanitize_sql([photo_ids_sql, { user_id: id }])
    )

    Photo.published
         .where(id: photo_ids)
         .includes(image_attachment: :blob)
         .recent
  end

  # Get photos hidden from profile (only for own profile)
  def hidden_photos_from_profile
    Photo.published
         .joins("INNER JOIN hidden_profile_photos ON hidden_profile_photos.photo_id = photos.id")
         .where(hidden_profile_photos: { user_id: id })
         .includes(image_attachment: :blob)
         .recent
  end

  # Get roles for a specific photo
  def photo_roles(photo)
    roles = []
    roles << 'Photographer' if photo.photographer_user_id == id
    roles << 'Rider' if photo.riders.include?(self)
    roles << 'Company' if photo.company_user_id == id
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

  # Hide a film from profile
  def hide_film_from_profile(film)
    hidden_profile_films.find_or_create_by(film: film)
  end

  # Unhide a film from profile
  def unhide_film_from_profile(film)
    hidden_profile_films.find_by(film: film)&.destroy
  end

  # Check if film is hidden from profile
  def film_hidden_from_profile?(film)
    hidden_profile_films.exists?(film: film)
  end

  # Hide a photo from profile
  def hide_photo_from_profile(photo)
    hidden_profile_photos.find_or_create_by(photo: photo)
  end

  # Unhide a photo from profile
  def unhide_photo_from_profile(photo)
    hidden_profile_photos.find_by(photo: photo)&.destroy
  end

  # Check if photo is hidden from profile
  def photo_hidden_from_profile?(photo)
    hidden_profile_photos.exists?(photo: photo)
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
  before_destroy :nullify_direct_content_roles

  # Update the cached films count for this user
  # Counts all unique films where user is tagged as rider, filmer, editor, or company
  def update_films_count!
    count = calculate_films_count
    update_column(:films_count, count)
  end

  # Calculate total unique films count without updating
  def calculate_films_count
    film_ids = Set.new
    film_ids.merge(rider_films.pluck(:id))
    film_ids.merge(filmer_films.pluck(:id))
    film_ids.merge(filmed_films.pluck(:id))
    film_ids.merge(edited_films.pluck(:id))
    film_ids.merge(multi_company_films.pluck(:id))
    film_ids.merge(company_films.pluck(:id))
    film_ids.size
  end

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

  def nullify_direct_content_roles
    # Detach authored/role references to avoid FK errors on destroy
    Film.where(filmer_user_id: id).update_all(filmer_user_id: nil)
    Film.where(editor_user_id: id).update_all(editor_user_id: nil)
    Film.where(company_user_id: id).update_all(company_user_id: nil)
    Film.where(user_id: id).update_all(user_id: nil)

    Photo.where(photographer_user_id: id).update_all(photographer_user_id: nil)
    Photo.where(company_user_id: id).update_all(company_user_id: nil)
    Photo.where(user_id: id).update_all(user_id: nil)
  end
end
