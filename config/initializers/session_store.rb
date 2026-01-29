# Configure session store to work with custom domain
# Don't set domain - let the browser handle it based on the current host
# This allows cookies to work on both streetwatch.mov and railway.app URLs
Rails.application.config.session_store :cookie_store,
  key: '_streetwatch_session',
  same_site: :lax,  # Allows cookies in cross-site GET requests (needed for OAuth, etc.)
  secure: Rails.env.production?,  # Only send cookies over HTTPS in production
  httponly: true,  # Prevent JavaScript access to session cookie for security
  expire_after: 2.weeks  # Session expires after 2 weeks of inactivity
