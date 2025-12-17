class Favorite < ApplicationRecord
  belongs_to :user
  belongs_to :film

  validates :user_id, uniqueness: { scope: :film_id }

  # Allow ActiveAdmin/Ransack to filter favorites by these fields
  def self.ransackable_attributes(auth_object = nil)
    %w[id user_id film_id created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[user film]
  end
end
