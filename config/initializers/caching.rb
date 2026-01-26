# config/initializers/caching.rb
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
