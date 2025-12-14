class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  has_one_attached :avatar
  has_many :film_riders, dependent: :destroy
  has_many :rider_films, through: :film_riders, source: :film
  has_many :filmed_films, class_name: 'Film', foreign_key: 'filmer_user_id'
  has_many :edited_films, class_name: 'Film', foreign_key: 'editor_user_id'

  # Favorites, comments, and playlists
  has_many :favorites, dependent: :destroy
  has_many :favorited_films, through: :favorites, source: :film
  has_many :comments, dependent: :destroy
  has_many :playlists, dependent: :destroy
  has_one :preference, class_name: 'UserPreference', dependent: :destroy

  validates :username, presence: true, uniqueness: { case_sensitive: false }, format: { with: /\A[a-zA-Z0-9_.]+\z/, message: "letters, numbers, underscore, and dot only" }
  validates :name, presence: true

  # Get all films associated with this user (as rider, filmer, or editor)
  def all_films
    Film.where(id: (rider_films.pluck(:id) + filmed_films.pluck(:id) + edited_films.pluck(:id)).uniq)
        .includes(thumbnail_attachment: :blob)
        .recent
  end

  # Get roles for a specific film
  def film_roles(film)
    roles = []
    roles << 'Filmer' if film.filmer_user_id == id
    roles << 'Editor' if film.editor_user_id == id
    roles << 'Rider' if film.riders.include?(self)
    roles
  end

  before_validation :normalize_username

  # Create or locate a user from an OmniAuth auth hash.
  def self.from_omniauth(auth)
    email = auth.info.email
    user = find_or_initialize_by(email: email)
    user.name ||= auth.info.name
    user.username ||= auth.info.email.split("@").first if auth.info.email.present?
    user.password ||= Devise.friendly_token[0, 20]
    user.save(validate: false)
    user
  end

  private

  def normalize_username
    self.username = username&.strip&.downcase
  end
end
