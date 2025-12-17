class AdminUser < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  # Role-based authorization
  ROLES = %w[super_admin admin moderator].freeze

  validates :role, inclusion: { in: ROLES }

  def super_admin?
    role == 'super_admin'
  end

  def admin?
    role == 'admin' || super_admin?
  end

  def moderator?
    role == 'moderator' || admin?
  end

  # Ransack configuration for ActiveAdmin filtering
  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "email", "id", "role", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end
end
