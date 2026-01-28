# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  # Override respond_with to force a full page reload after login
  # This prevents cached pages from showing stale authentication state
  def respond_with(resource, _opts = {})
    if resource.persisted?
      # Log successful authentication
      Rails.logger.info "[AUTH DEBUG] User #{resource.id} signed in successfully from #{request.remote_ip}"

      # Force a full page reload with explicit redirect
      redirect_to after_sign_in_path_for(resource), turbo: false, allow_other_host: false
    else
      Rails.logger.warn "[AUTH DEBUG] Failed login attempt for #{params[:user]&.dig(:email) || 'unknown'}"
      super
    end
  end

  # Override create to ensure session is properly established
  def create
    Rails.logger.info "[AUTH DEBUG] Login attempt for: #{params[:user]&.dig(:email)}"
    Rails.logger.info "[AUTH DEBUG] Request host: #{request.host}"
    Rails.logger.info "[AUTH DEBUG] Request format: #{request.format}"
    Rails.logger.info "[AUTH DEBUG] CSRF token present: #{params[:authenticity_token].present?}"
    Rails.logger.info "[AUTH DEBUG] Session ID before auth: #{session.id.inspect}"

    begin
      self.resource = warden.authenticate!(auth_options)
      set_flash_message!(:notice, :signed_in)

      # Sign in the user and ensure remember_me works if checked
      remember_me_value = params[:user][:remember_me] == '1'
      Rails.logger.info "[AUTH DEBUG] Remember me: #{remember_me_value}"
      sign_in(resource_name, resource, remember: remember_me_value)

      # Log the session details for debugging
      Rails.logger.info "[AUTH DEBUG] Session ID after auth: #{session.id.inspect}"
      Rails.logger.info "[AUTH DEBUG] Warden user set: #{warden.user(:user)&.id}"
      Rails.logger.info "[AUTH DEBUG] Cookies being set: #{response.headers['Set-Cookie']&.split("\n")&.map { |c| c.split('=').first }}"

      yield resource if block_given?
      respond_with resource, location: after_sign_in_path_for(resource)
    rescue => e
      Rails.logger.error "[AUTH DEBUG] Authentication error: #{e.class} - #{e.message}"
      Rails.logger.error "[AUTH DEBUG] Backtrace: #{e.backtrace.first(5).join("\n")}"
      raise
    end
  end
end
