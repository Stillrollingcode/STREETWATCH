# Middleware to ensure session cookies work properly through CloudFlare proxy
# This middleware ensures cookies are set with the correct domain for streetwatch.mov
# even when accessed through CloudFlare's proxy or different subdomains

class CloudflareSessionFix
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)
    request = Rack::Request.new(env)

    # Log cookie handling for auth-related paths
    if request.path.include?('sign_in') || request.path.include?('session')
      Rails.logger.info "[COOKIE DEBUG] Path: #{request.path}"
      Rails.logger.info "[COOKIE DEBUG] Host: #{request.host}"
      Rails.logger.info "[COOKIE DEBUG] Original Set-Cookie: #{headers['Set-Cookie']&.split("\n")&.map { |c| c.split(';').first }}"
    end

    # Fix cookie domain for streetwatch.mov requests
    # This ensures cookies work whether accessed via www.streetwatch.mov or streetwatch.mov
    if headers['Set-Cookie']
      # Only modify cookies for streetwatch.mov domain (not Railway URLs)
      if request.host&.end_with?("streetwatch.mov")
        cookies = headers['Set-Cookie'].split("\n")
        fixed_cookies = cookies.map do |cookie|
          # Fix session and remember_me cookies
          if cookie.include?('_streetwatch_session') || cookie.include?('remember_user_token')
            original_cookie = cookie.dup
            # Remove any existing Domain attribute (may be set incorrectly)
            cookie = cookie.gsub(/;\s*Domain=[^;]*/i, '')
            # Set domain to .streetwatch.mov (leading dot allows subdomains)
            cookie += '; Domain=.streetwatch.mov'
            # Ensure SameSite=Lax is present
            cookie = cookie.gsub(/;\s*SameSite=[^;]*/i, '')
            cookie += '; SameSite=Lax'
            # Ensure Secure flag is present for HTTPS
            unless cookie.downcase.include?('secure')
              cookie += '; Secure'
            end
            Rails.logger.info "[COOKIE DEBUG] Modified cookie from: #{original_cookie.split(';').first}"
            Rails.logger.info "[COOKIE DEBUG] Modified cookie to: #{cookie}"
          end
          cookie
        end
        headers['Set-Cookie'] = fixed_cookies.join("\n")
      end
    end

    [status, headers, response]
  end
end

Rails.application.config.middleware.use CloudflareSessionFix
