class PagesController < ApplicationController
  def home
    # Set cache headers for CDN (5 minutes for logged-out users)
    expires_in 5.minutes, public: true unless user_signed_in?

    # Landing page uses the application layout content; add content_for sections here later as needed.
  end

  def about
  end

  def subscription
  end

  def privacy
  end

  def sellers_disclaimer
  end
end
