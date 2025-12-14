class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :film
  belongs_to :parent, class_name: 'Comment', optional: true
  has_many :replies, class_name: 'Comment', foreign_key: 'parent_id', dependent: :destroy

  validates :body, presence: true, length: { minimum: 1, maximum: 5000 }

  scope :recent, -> { order(created_at: :desc) }
  scope :top_level, -> { where(parent_id: nil) }
end
