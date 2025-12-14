class UserPreference < ApplicationRecord
  belongs_to :user

  validates :theme, inclusion: { in: %w[light dark] }
  validates :accent_hue, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 360 }

  # Generate CSS color values from hue
  def accent_color
    "hsl(#{accent_hue}, 45%, 45%)"
  end

  def accent_color_light
    "hsl(#{accent_hue}, 45%, 55%)"
  end

  def accent_rgba(opacity = 1)
    # Convert HSL to RGB for rgba
    h = accent_hue / 360.0
    s = 0.45
    l = 0.45

    if s == 0
      r = g = b = l
    else
      q = l < 0.5 ? l * (1 + s) : l + s - l * s
      p = 2 * l - q
      r = hue_to_rgb(p, q, h + 1/3.0)
      g = hue_to_rgb(p, q, h)
      b = hue_to_rgb(p, q, h - 1/3.0)
    end

    "rgba(#{(r * 255).round}, #{(g * 255).round}, #{(b * 255).round}, #{opacity})"
  end

  private

  def hue_to_rgb(p, q, t)
    t += 1 if t < 0
    t -= 1 if t > 1
    return p + (q - p) * 6 * t if t < 1/6.0
    return q if t < 1/2.0
    return p + (q - p) * (2/3.0 - t) * 6 if t < 2/3.0
    p
  end
end
