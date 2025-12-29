class TagRequest < ApplicationRecord
  belongs_to :film
  belongs_to :requester, class_name: 'User'

  ROLES = %w[rider filmer company editor].freeze
  STATUSES = %w[pending approved denied].freeze

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :film_id, uniqueness: { scope: [:requester_id, :role], message: "You already have a pending request for this role" }

  scope :pending, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :denied, -> { where(status: 'denied') }

  def approve!
    return false unless pending?

    transaction do
      # Add the user to the appropriate association based on role
      case role
      when 'rider'
        film.riders << requester unless film.riders.include?(requester)
      when 'filmer'
        film.filmers << requester unless film.filmers.include?(requester)
      when 'company'
        film.companies << requester unless film.companies.include?(requester)
      when 'editor'
        film.update(editor_user: requester)
      end

      update(status: 'approved')
    end
  end

  def deny!
    update(status: 'denied')
  end

  def pending?
    status == 'pending'
  end

  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "film_id", "id", "message", "requester_id", "role", "status", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["film", "requester"]
  end
end
