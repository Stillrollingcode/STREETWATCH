class ApplicationController < ActionController::Base
  # Allow Chrome/Edge 109+ while keeping the unsupported-browser guard.
  allow_browser versions: { chrome: 109, edge: 109 }
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    preference_keys = [
      :id,
      :email_notifications_enabled,
      :notify_on_new_follower,
      :notify_on_comment,
      :notify_on_mention,
      :notify_on_favorite,
      :content_tab_order
    ]

    allowed_keys = [
      :name,
      :username,
      :avatar,
      :bio,
      :sponsor_requests,
      :profile_type,
      :email_visible,
      { preference_attributes: preference_keys },
      { sponsor_ids: [] }
    ]

    devise_parameter_sanitizer.permit(:sign_up, keys: allowed_keys)
    devise_parameter_sanitizer.permit(:account_update, keys: allowed_keys)
  end

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
