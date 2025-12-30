# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  # Override respond_with to force a full page reload after login
  # This prevents cached pages from showing stale authentication state
  def respond_with(resource, _opts = {})
    if resource.persisted?
      # Force a full page reload by using turbo: false
      redirect_to after_sign_in_path_for(resource), turbo: false
    else
      super
    end
  end
end
