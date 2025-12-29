class Film < ApplicationRecord
  include FriendlyIdentifiable
  include Searchable

  has_one_attached :thumbnail
  has_one_attached :video

  # Multiple quality versions for transcoded videos
  has_one_attached :video_4k      # 3840x2160
  has_one_attached :video_2k      # 2560x1440
  has_one_attached :video_1080p   # 1920x1080
  has_one_attached :video_720p    # 1280x720
  has_one_attached :video_480p    # 854x480
  has_one_attached :video_360p    # 640x360

  # Rider associations (profile users)
  has_many :film_riders, dependent: :destroy
  has_many :riders, through: :film_riders, source: :user

  # Filmer associations (multiple filmers supported)
  has_many :film_filmers, dependent: :destroy
  has_many :filmers, through: :film_filmers, source: :user

  # Company associations (multiple companies supported)
  has_many :film_companies, dependent: :destroy
  has_many :companies, through: :film_companies, source: :user

  # User who uploaded the film
  belongs_to :user, optional: true

  # Legacy single filmer/company/editor associations (kept for backwards compatibility)
  belongs_to :filmer_user, class_name: 'User', optional: true
  belongs_to :editor_user, class_name: 'User', optional: true
  belongs_to :company_user, class_name: 'User', optional: true

  # Favorites, comments, and playlists
  has_many :favorites, dependent: :destroy
  has_many :favorited_by_users, through: :favorites, source: :user
  has_many :comments, dependent: :destroy
  has_many :playlist_films, dependent: :destroy
  has_many :playlists, through: :playlist_films

  # Approvals for tagged profiles
  has_many :film_approvals, dependent: :destroy
  has_many :pending_approvals, -> { pending }, class_name: 'FilmApproval'

  # Tag requests from users asking to be tagged
  has_many :tag_requests, dependent: :destroy
  has_many :pending_tag_requests, -> { pending }, class_name: 'TagRequest'

  # Hidden from profile associations
  has_many :hidden_profile_films, dependent: :destroy
  has_many :hidden_by_users, through: :hidden_profile_films, source: :user

  FILM_TYPES = %w[full_length rider_part mixtape series b_sides all_the_rest].freeze

  FILM_TYPE_DESCRIPTIONS = {
    'full_length' => 'A large production video featuring sections from numerous riders, usually lasting at least 40 minutes',
    'rider_part' => 'A video featuring a full part from 1-2 riders, sometimes reposted from a full length project',
    'mixtape' => 'A mix of clips from various riders, usually lasting from 10-30 minutes',
    'series' => 'A recurring edit, usually with a theme',
    'b_sides' => 'Raw, behind the scenes footage from the making of another project',
    'all_the_rest' => 'Anything that does not fall into one of these categories such as documentaries, commentary, or interviews'
  }.freeze

  validates :title, presence: true
  validates :film_type, inclusion: { in: FILM_TYPES }
  validate :video_source_exclusivity
  validate :video_source_required

  # Process video in background after commit
  # TEMPORARILY DISABLED for development performance
  # after_commit :enqueue_video_processing, on: [:create, :update], if: :video_attached?
  after_commit :create_approval_requests, on: [:create, :update]
  after_commit :download_youtube_thumbnail, on: [:create, :update], if: :should_download_youtube_thumbnail?

  scope :recent, -> { order(release_date: :desc, created_at: :desc) }
  scope :by_company, ->(company) { where(company: company) if company.present? }
  scope :by_type, ->(type) { where(film_type: type) if type.present? }
  scope :published, -> { where(id: Film.select(:id).left_joins(:film_approvals).group(:id).having('COUNT(CASE WHEN film_approvals.status = ? THEN 1 END) = 0', 'pending')) }

  def formatted_runtime
    return nil unless runtime.present?
    minutes = runtime
    hours = minutes / 60
    remaining_minutes = minutes % 60

    if hours > 0
      "#{hours}:#{remaining_minutes.to_s.rjust(2, '0')}"
    else
      "#{remaining_minutes}:00"
    end
  end

  def formatted_film_type
    film_type.to_s.titleize.gsub('_', ' ')
  end

  def film_type_description
    FILM_TYPE_DESCRIPTIONS[film_type]
  end

  def self.film_type_description(type)
    FILM_TYPE_DESCRIPTIONS[type]
  end

  def filmer_display_name
    filmer_user&.username || custom_filmer_name
  end

  def filmers_display_names
    filmer_names = filmers.pluck(:username)
    custom_filmer_list = custom_filmer_name.to_s.split(',').map(&:strip).reject(&:blank?)
    all_filmers = (filmer_names + custom_filmer_list).uniq
    all_filmers.empty? ? [filmer_display_name].compact : all_filmers
  end

  def editor_display_name
    editor_user&.username || custom_editor_name
  end

  def company_display_name
    company_user&.username || company
  end

  def companies_display_names
    company_names = companies.pluck(:username)
    custom_company_list = company.to_s.split(',').map(&:strip).reject(&:blank?)
    all_companies = (company_names + custom_company_list).uniq
    all_companies.empty? ? [company_display_name].compact : all_companies
  end

  def all_riders_display
    profile_riders = riders.pluck(:username)
    custom_rider_list = custom_riders.to_s.split("\n").map(&:strip).reject(&:blank?)
    (profile_riders + custom_rider_list).uniq
  end

  def aspect_ratio_css
    return '16 / 9' unless aspect_ratio.present?

    # Convert "16:9" to "16 / 9" for CSS aspect-ratio property
    aspect_ratio.gsub(':', ' / ')
  end

  def youtube_video_id
    return nil unless youtube_url.present?

    # Extract video ID from various YouTube URL formats
    # https://www.youtube.com/watch?v=VIDEO_ID
    # https://youtu.be/VIDEO_ID
    # https://youtu.be/VIDEO_ID?si=TRACKING_ID
    # https://www.youtube.com/embed/VIDEO_ID
    if youtube_url.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([a-zA-Z0-9_-]{11})/)
      $1
    end
  end

  def has_video?
    video.attached? || youtube_url.present?
  end

  def youtube_thumbnail_url(quality = 'maxresdefault')
    return nil unless youtube_video_id

    # Quality options: default, mqdefault, hqdefault, sddefault, maxresdefault
    "https://img.youtube.com/vi/#{youtube_video_id}/#{quality}.jpg"
  end

  def display_thumbnail
    if thumbnail.attached?
      thumbnail
    elsif youtube_thumbnail_url
      # This will only be used if thumbnail download failed or hasn't happened yet
      youtube_thumbnail_url
    else
      nil
    end
  end

  def published?
    pending_approvals.empty?
  end

  def requires_approvals?
    filmers.any? || companies.any? || editor_user.present? || riders.any? ||
    filmer_user.present? || company_user.present?
  end

  def tagged_users
    users = []
    # New multi-select associations
    users += filmers.to_a
    users += companies.to_a
    users << editor_user if editor_user.present?
    users += riders.to_a
    # Legacy single associations
    users << filmer_user if filmer_user.present?
    users << company_user if company_user.present?
    users.uniq
  end

  private

  def should_download_youtube_thumbnail?
    # Download YouTube thumbnail if:
    # 1. There's a YouTube URL
    # 2. No thumbnail is currently attached
    # 3. YouTube URL has changed (for updates)
    youtube_url.present? && !thumbnail.attached? && youtube_video_id.present?
  end

  def download_youtube_thumbnail
    require 'open-uri'

    begin
      Rails.logger.info "[FILM #{id}] Downloading YouTube thumbnail from: #{youtube_thumbnail_url}"

      # Try maxresdefault first (highest quality)
      thumbnail_url = youtube_thumbnail_url('maxresdefault')
      downloaded_image = URI.open(thumbnail_url)

      # Check if we got the default placeholder image (120x90)
      # YouTube returns a small placeholder if maxresdefault doesn't exist
      if downloaded_image.size < 5000
        Rails.logger.info "[FILM #{id}] maxresdefault not available, trying hqdefault..."
        downloaded_image.close
        thumbnail_url = youtube_thumbnail_url('hqdefault')
        downloaded_image = URI.open(thumbnail_url)
      end

      # Attach the downloaded image
      thumbnail.attach(
        io: downloaded_image,
        filename: "#{title.parameterize}_youtube_thumbnail.jpg",
        content_type: 'image/jpeg'
      )

      Rails.logger.info "[FILM #{id}] Successfully downloaded and attached YouTube thumbnail"
    rescue => e
      Rails.logger.error "[FILM #{id}] Failed to download YouTube thumbnail: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Don't raise error - thumbnail download failure shouldn't break film creation
    ensure
      downloaded_image&.close
    end
  end

  def create_approval_requests
    # Get all currently tagged users
    current_tagged_users = []

    # New multi-select associations
    filmers.each { |filmer| current_tagged_users << { user: filmer, type: 'filmer' } }
    companies.each { |company| current_tagged_users << { user: company, type: 'company' } }
    riders.each { |rider| current_tagged_users << { user: rider, type: 'rider' } }

    # Legacy single associations
    current_tagged_users << { user: filmer_user, type: 'filmer' } if filmer_user.present?
    current_tagged_users << { user: company_user, type: 'company' } if company_user.present?
    current_tagged_users << { user: editor_user, type: 'editor' } if editor_user.present?

    # Remove approvals for users no longer tagged
    existing_approvals = film_approvals.to_a
    existing_approvals.each do |approval|
      tagged_match = current_tagged_users.find { |t| t[:user].id == approval.approver_id && t[:type] == approval.approval_type }
      approval.destroy unless tagged_match
    end

    # Create new approval requests for newly tagged users
    current_tagged_users.each do |tag|
      next if film_approvals.exists?(approver: tag[:user], approval_type: tag[:type])

      # Auto-approve if user is tagging themselves
      status = (tag[:user].id == self.user_id) ? 'approved' : 'pending'

      film_approvals.create!(
        approver: tag[:user],
        approval_type: tag[:type],
        status: status
      )
    end
  rescue => e
    Rails.logger.error "Failed to create approval requests for film #{id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def video_source_exclusivity
    if video.attached? && youtube_url.present?
      errors.add(:base, "Cannot have both a video upload and a YouTube URL. Please choose one.")
    end
  end

  def video_source_required
    unless video.attached? || youtube_url.present?
      errors.add(:base, "You must provide either a video upload or a YouTube URL.")
    end
  end

  def video_attached?
    video.attached?
  end

  def video_attached_and_no_thumbnail?
    video.attached? && !thumbnail.attached?
  end

  def enqueue_video_processing
    # Process if video is attached and either:
    # 1. This is a new record
    # 2. The video was recently changed
    if video.attached?
      ProcessVideoJob.perform_later(id)
      Rails.logger.info "Enqueued video processing job for film #{id}"
    end
  end

  def available_qualities
    qualities = []
    qualities << { quality: '4K', url: rails_blob_path(video_4k, disposition: "attachment") } if video_4k.attached?
    qualities << { quality: '2K', url: rails_blob_path(video_2k, disposition: "attachment") } if video_2k.attached?
    qualities << { quality: '1080p', url: rails_blob_path(video_1080p, disposition: "attachment") } if video_1080p.attached?
    qualities << { quality: '720p', url: rails_blob_path(video_720p, disposition: "attachment") } if video_720p.attached?
    qualities << { quality: '480p', url: rails_blob_path(video_480p, disposition: "attachment") } if video_480p.attached?
    qualities << { quality: '360p', url: rails_blob_path(video_360p, disposition: "attachment") } if video_360p.attached?
    qualities << { quality: 'Original', url: rails_blob_path(video, disposition: "attachment") } if video.attached?
    qualities
  end

  # Keep these methods for manual processing if needed
  def generate_thumbnail_from_video
    return unless video.attached?

    # Download video to a temporary file for processing
    video.download do |file|
      movie = FFMPEG::Movie.new(file.path)

      # Create a temporary file for the screenshot
      screenshot_path = Rails.root.join('tmp', "screenshot_#{id}_#{Time.current.to_i}.png")

      # Take screenshot at 1 second (or 10% into the video)
      time = [movie.duration * 0.1, 1].max

      # Calculate resolution based on video aspect ratio to maintain quality
      # Use video's native resolution if available, or scale to maintain aspect ratio
      width = movie.width || 1280
      height = movie.height || 720

      # Scale down if too large while maintaining aspect ratio
      max_width = 1920
      if width > max_width
        scale_factor = max_width.to_f / width
        width = max_width
        height = (height * scale_factor).to_i
      end

      movie.screenshot(screenshot_path.to_s, seek_time: time, resolution: "#{width}x#{height}")

      # Attach the screenshot as thumbnail
      if File.exist?(screenshot_path)
        thumbnail.attach(
          io: File.open(screenshot_path),
          filename: "#{title.parameterize}_thumbnail.png",
          content_type: 'image/png'
        )

        # Clean up temporary file
        File.delete(screenshot_path)
      end
    end
  rescue => e
    Rails.logger.error "Failed to generate thumbnail for film #{id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def extract_video_metadata
    return unless video.attached?

    video.download do |file|
      movie = FFMPEG::Movie.new(file.path)

      # Extract runtime in minutes (rounded)
      duration_in_minutes = (movie.duration / 60.0).round

      # Calculate aspect ratio from video dimensions
      if movie.width && movie.height && movie.width > 0 && movie.height > 0
        width = movie.width.to_f
        height = movie.height.to_f
        ratio = width / height

        # Determine closest common aspect ratio
        calculated_ratio = case ratio
        when 0.5..0.6   # Close to 9:16 (0.5625)
          '9:16'
        when 0.7..0.8   # Close to 4:5 (0.8)
          '4:5'
        when 1.2..1.4   # Close to 4:3 (1.333)
          '4:3'
        when 1.7..1.8   # Close to 16:9 (1.777)
          '16:9'
        when 2.3..2.4   # Close to 21:9 (2.333)
          '21:9'
        else
          # Default to 16:9 or use custom ratio string
          "#{width.to_i}:#{height.to_i}"
        end

        update_column(:aspect_ratio, calculated_ratio) if aspect_ratio != calculated_ratio
      end

      # Update runtime if it's not already set or if video changed
      update_column(:runtime, duration_in_minutes) if runtime != duration_in_minutes
    end
  rescue => e
    Rails.logger.error "Failed to extract video metadata for film #{id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  # Friendly ID prefix for films: F####
  def self.friendly_id_prefix
    "F"
  end

  # Ransack configuration for ActiveAdmin filtering
  def self.ransackable_attributes(auth_object = nil)
    ["aspect_ratio", "company", "company_user_id", "created_at", "custom_editor_name", "custom_filmer_name",
     "custom_riders", "description", "editor_user_id", "film_type", "filmer_user_id", "id",
     "music_featured", "parent_film_title", "release_date", "runtime", "title", "updated_at", "user_id", "youtube_url", "friendly_id"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["riders", "filmer_user", "editor_user", "company_user", "favorites", "comments", "playlists"]
  end
end
