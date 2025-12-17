module FriendlyIdentifiable
  extend ActiveSupport::Concern

  included do
    before_create :generate_friendly_id
    validates :friendly_id, uniqueness: true, allow_nil: true
  end

  # Override to_param to use friendly_id in URLs
  def to_param
    friendly_id || id.to_s
  end

  private

  def generate_friendly_id
    return if friendly_id.present?

    prefix = self.class.friendly_id_prefix
    max_id = self.class.where("friendly_id LIKE ?", "#{prefix}%")
                      .maximum(:friendly_id)

    if max_id
      # Extract number from existing friendly_id and increment
      number = max_id.gsub(/\D/, '').to_i + 1
    else
      # Start from 1
      number = 1
    end

    self.friendly_id = "#{prefix}#{number.to_s.rjust(4, '0')}"
  end

  class_methods do
    def friendly_id_prefix
      raise NotImplementedError, "#{name} must define friendly_id_prefix class method"
    end

    # Find by either friendly_id or regular id
    def find_by_friendly_or_id(param)
      find_by(friendly_id: param) || find(param)
    end
  end
end
