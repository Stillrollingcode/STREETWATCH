# config/initializers/caching.rb
# Simplified caching configuration for StreetWatch

Rails.application.configure do
  # Cache store configuration
  if Rails.env.production?
    # Use Redis for cache store in production (if available)
    if ENV['REDIS_URL'].present?
      config.cache_store = :redis_cache_store, {
        url: ENV['REDIS_URL'],
        expires_in: 1.hour,
        namespace: 'streetwatch_cache',
        pool_size: ENV.fetch("RAILS_MAX_THREADS") { 5 }.to_i,
        pool_timeout: 5,

        # Compression for large cached values
        compress: true,
        compress_threshold: 1.kilobyte,

        # Race condition TTL to prevent cache stampedes
        race_condition_ttl: 10.seconds,

        # Error handling
        error_handler: ->(method:, returning:, exception:) {
          Rails.logger.error "Cache error: #{exception.message}"
        }
      }
    else
      # Fallback to memory store if Redis not available
      config.cache_store = :memory_store, { size: 128.megabytes }
    end
  else
    # Use memory store in development/test
    config.cache_store = :memory_store, { size: 64.megabytes }
  end

  # Enable fragment caching
  config.action_controller.perform_caching = true
end

# Cache key helpers module
module CacheKeyHelpers
  # Generate cache key with versioning
  def self.versioned_key(key, version = 1)
    "v#{version}:#{key}"
  end

  # User-specific cache key
  def self.user_cache_key(user, key)
    "user:#{user.id}:#{key}"
  end

  # Film cache key with timestamp
  def self.film_cache_key(film)
    "film:#{film.id}:#{film.updated_at.to_i}"
  end

  # Photo cache key with timestamp
  def self.photo_cache_key(photo)
    "photo:#{photo.id}:#{photo.updated_at.to_i}"
  end
end
