class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    preference_keys = [
      :id,
      :email_notifications_enabled,
      :notify_on_new_follower,
      :notify_on_comment,
      :notify_on_mention,
      :notify_on_favorite
    ]

    allowed_keys = [
      :name,
      :username,
      :avatar,
      :bio,
      :sponsor_requests,
      :profile_type,
      :email_visible,
      { preference_attributes: preference_keys }
    ]

    devise_parameter_sanitizer.permit(:sign_up, keys: allowed_keys)
    devise_parameter_sanitizer.permit(:account_update, keys: allowed_keys)
  end

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
