# Middleware to ensure session cookies work properly through CloudFlare proxy
# This middleware ensures cookies are set with the correct domain for streetwatch.mov
# even when accessed through CloudFlare's proxy or different subdomains

class CloudflareSessionFix
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)

    # Fix cookie domain for streetwatch.mov requests
    # This ensures cookies work whether accessed via www.streetwatch.mov or streetwatch.mov
    if headers['Set-Cookie']
      request = Rack::Request.new(env)

      # Only modify cookies for streetwatch.mov domain (not Railway URLs)
      if request.host&.end_with?("streetwatch.mov")
        cookies = headers['Set-Cookie'].split("\n")
        fixed_cookies = cookies.map do |cookie|
          # Fix session and remember_me cookies
          if cookie.include?('_streetwatch_session') || cookie.include?('remember_user_token')
            # Remove any existing Domain attribute (may be set incorrectly)
            cookie = cookie.gsub(/;\s*Domain=[^;]*/i, '')
            # Set domain to .streetwatch.mov (leading dot allows subdomains)
            cookie += '; Domain=.streetwatch.mov'
            # Ensure SameSite=Lax is present
            cookie = cookie.gsub(/;\s*SameSite=[^;]*/i, '')
            cookie += '; SameSite=Lax'
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
