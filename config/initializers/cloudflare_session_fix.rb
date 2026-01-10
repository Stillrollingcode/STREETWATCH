# Middleware to ensure session cookies work properly through CloudFlare proxy
# CloudFlare can sometimes strip or modify cookies, this ensures they persist

class CloudflareSessionFix
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)

    # Force session cookie to be set with proper attributes for CloudFlare
    if headers['Set-Cookie']
      # Ensure SameSite=Lax is set (CloudFlare requires this)
      cookies = headers['Set-Cookie'].split("\n")
      fixed_cookies = cookies.map do |cookie|
        if cookie.include?('_streetwatch_session')
          # Remove any existing SameSite attribute
          cookie = cookie.gsub(/;\s*SameSite=[^;]+/i, '')
          # Add SameSite=Lax
          cookie += '; SameSite=Lax' unless cookie.include?('SameSite')
          cookie
        else
          cookie
        end
      end
      headers['Set-Cookie'] = fixed_cookies.join("\n")
    end

    [status, headers, response]
  end
end

Rails.application.config.middleware.use CloudflareSessionFix
