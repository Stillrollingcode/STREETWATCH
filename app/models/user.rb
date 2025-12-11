class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2]
         
  has_one_attached :avatar

  validates :username, presence: true, uniqueness: { case_sensitive: false }, format: { with: /\A[a-zA-Z0-9_.]+\z/, message: "letters, numbers, underscore, and dot only" }
  validates :name, presence: true

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
