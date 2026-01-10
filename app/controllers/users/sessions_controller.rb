# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  # Skip CSRF verification for session create to help with cross-domain issues
  skip_forgery_protection only: [:create], if: -> { request.format.html? }

  # Override respond_with to force a full page reload after login
  # This prevents cached pages from showing stale authentication state
  def respond_with(resource, _opts = {})
    if resource.persisted?
      # Log successful authentication
      Rails.logger.info "User #{resource.id} signed in successfully from #{request.remote_ip}"

      # Force a full page reload with explicit redirect
      redirect_to after_sign_in_path_for(resource), turbo: false, allow_other_host: false
    else
      Rails.logger.warn "Failed login attempt for #{params[:user]&.dig(:email) || 'unknown'}"
      super
    end
  end

  # Override create to ensure session is properly established
  def create
    self.resource = warden.authenticate!(auth_options)
    set_flash_message!(:notice, :signed_in)

    # Sign in the user and ensure remember_me works if checked
    sign_in(resource_name, resource, remember: params[:user][:remember_me] == '1')

    # Log the session details for debugging
    Rails.logger.info "Session ID: #{session.id.inspect}"
    Rails.logger.info "Warden user: #{warden.user(:user).inspect}"

    yield resource if block_given?
    respond_with resource, location: after_sign_in_path_for(resource)
  end
end
