module ThemeHelper
  def user_theme_styles
    return default_theme_styles unless user_signed_in? && current_user.preference

    pref = current_user.preference
    hue = pref.accent_hue

    # Calculate RGB values from HSL
    h = hue / 360.0
    s = 0.45
    l_primary = 0.45
    l_secondary = 0.35
    l_light = 0.55

    primary_rgb = hsl_to_rgb(h, s, l_primary)
    secondary_rgb = hsl_to_rgb(h, s, l_secondary)
    light_rgb = hsl_to_rgb(h, s, l_light)

    if pref.theme == "light"
      light_theme_styles(hue, primary_rgb, secondary_rgb, light_rgb).merge(theme_name: 'light')
    else
      dark_theme_styles(hue, primary_rgb, secondary_rgb, light_rgb).merge(theme_name: 'dark')
    end
  end

  private

  def default_theme_styles
    dark_theme_styles(145, [74, 140, 94], [45, 90, 61], [91, 168, 118]).merge(theme_name: 'dark')
  end

  def dark_theme_styles(hue, primary_rgb, secondary_rgb, light_rgb)
    {
      bg: "#0d0d10",
      panel: "rgba(255,255,255,0.06)",
      text: "#eae7e2",
      muted: "#a8a3a0",
      accent: "hsl(#{hue}, 45%, 45%)",
      accent_2: "hsl(#{hue}, 45%, 35%)",
      accent_hue: hue,
      border: "rgba(255,255,255,0.12)",
      body_bg_1: "rgba(#{primary_rgb.join(',')}, 0.12)",
      body_bg_2: "rgba(#{secondary_rgb.join(',')}, 0.16)",
      body_bg_base: "#0a0a0c",
      gradient_1: "rgba(#{primary_rgb.join(',')}, 0.28)",
      gradient_2: "rgba(#{secondary_rgb.join(',')}, 0.35)",
      primary_rgba: "rgba(#{primary_rgb.join(',')}, ALPHA)",
      secondary_rgba: "rgba(#{secondary_rgb.join(',')}, ALPHA)",
      light_rgba: "rgba(#{light_rgb.join(',')}, ALPHA)",
      nav_bg: "rgba(13,13,16,0.9)",
      sidebar_bg: "#0f0f12"
    }
  end

  def light_theme_styles(hue, primary_rgb, secondary_rgb, light_rgb)
    {
      bg: "#f5f5f7",
      panel: "rgba(0,0,0,0.04)",
      text: "#1d1d1f",
      muted: "#6e6e73",
      accent: "hsl(#{hue}, 50%, 40%)",
      accent_2: "hsl(#{hue}, 50%, 30%)",
      accent_hue: hue,
      border: "rgba(0,0,0,0.12)",
      body_bg_1: "rgba(#{primary_rgb.join(',')}, 0.08)",
      body_bg_2: "rgba(#{secondary_rgb.join(',')}, 0.12)",
      body_bg_base: "#ffffff",
      gradient_1: "rgba(#{primary_rgb.join(',')}, 0.18)",
      gradient_2: "rgba(#{secondary_rgb.join(',')}, 0.25)",
      primary_rgba: "rgba(#{primary_rgb.join(',')}, ALPHA)",
      secondary_rgba: "rgba(#{secondary_rgb.join(',')}, ALPHA)",
      light_rgba: "rgba(#{light_rgb.join(',')}, ALPHA)",
      nav_bg: "rgba(255,255,255,0.9)",
      sidebar_bg: "#ffffff"
    }
  end

  def hsl_to_rgb(h, s, l)
    if s == 0
      r = g = b = l
    else
      q = l < 0.5 ? l * (1 + s) : l + s - l * s
      p = 2 * l - q
      r = hue_to_rgb(p, q, h + 1/3.0)
      g = hue_to_rgb(p, q, h)
      b = hue_to_rgb(p, q, h - 1/3.0)
    end

    [(r * 255).round, (g * 255).round, (b * 255).round]
  end

  def hue_to_rgb(p, q, t)
    t += 1 if t < 0
    t -= 1 if t > 1
    return p + (q - p) * 6 * t if t < 1/6.0
    return q if t < 1/2.0
    return p + (q - p) * (2/3.0 - t) * 6 if t < 2/3.0
    p
  end
end
