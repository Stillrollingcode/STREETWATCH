# Middleware to log cookie handling for debugging auth issues
# Can be removed once auth is working reliably

class CloudflareSessionFix
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)
    request = Rack::Request.new(env)

    # Log cookie handling for auth-related paths (for debugging)
    if request.path.include?('sign_in') || request.path.include?('session')
      Rails.logger.info "[COOKIE DEBUG] Path: #{request.path}"
      Rails.logger.info "[COOKIE DEBUG] Host: #{request.host}"
      Rails.logger.info "[COOKIE DEBUG] Set-Cookie: #{headers['Set-Cookie']&.split("\n")&.map { |c| c.split(';').first }}"
    end

    [status, headers, response]
  end
end

Rails.application.config.middleware.use CloudflareSessionFix
