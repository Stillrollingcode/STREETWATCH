# Configure session store to work with custom domain
# Set domain explicitly for streetwatch.mov to ensure cookies work on the custom domain
Rails.application.config.session_store :cookie_store,
  key: '_streetwatch_session',
  same_site: :lax,  # Allows cookies in cross-site GET requests (needed for OAuth, etc.)
  secure: Rails.env.production?,  # Only send cookies over HTTPS in production
  httponly: true,  # Prevent JavaScript access to session cookie for security
  expire_after: 2.weeks,  # Session expires after 2 weeks of inactivity
  domain: :all,  # Allow cookies to work across subdomains (www.streetwatch.mov, streetwatch.mov)
  tld_length: 2  # streetwatch.mov has 2 parts (streetwatch + mov)
