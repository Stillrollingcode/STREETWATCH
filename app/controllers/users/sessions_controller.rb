# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  # Skip CSRF verification for login - Devise handles authentication security
  # This fixes issues with Cloudflare proxy and cookie domain mismatches
  skip_before_action :verify_authenticity_token, only: [:create]

  # Override respond_with to force a full page reload after login
  # This prevents cached pages from showing stale authentication state
  def respond_with(resource, _opts = {})
    if resource.persisted?
      # Force a full page reload with explicit redirect
      redirect_to after_sign_in_path_for(resource), turbo: false, allow_other_host: false
    else
      super
    end
  end
end
