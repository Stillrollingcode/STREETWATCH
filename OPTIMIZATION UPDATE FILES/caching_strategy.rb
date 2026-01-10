# config/initializers/caching_strategy.rb
# Comprehensive caching configuration for StreetWatch

Rails.application.configure do
  # Enable fragment caching in production
  config.action_controller.perform_caching = Rails.env.production?
  
  # Use Redis for cache store in production
  if Rails.env.production?
    config.cache_store = :redis_cache_store, {
      url: ENV['REDIS_URL'] || 'redis://localhost:6379/1',
      expires_in: 1.hour,
      namespace: 'streetwatch_cache',
      pool_size: 5,
      pool_timeout: 5,
      
      # Compression for large cached values
      compress: true,
      compress_threshold: 1.kilobyte,
      
      # Race condition TTL to prevent cache stampedes
      race_condition_ttl: 10.seconds,
      
      # Error handling
      error_handler: -> (method:, returning:, exception:) {
        Rails.logger.error "Cache error: #{exception.message}"
        Sentry.capture_exception(exception) if defined?(Sentry)
      }
    }
  else
    # Use memory store in development/test
    config.cache_store = :memory_store, { size: 64.megabytes }
  end
end

# Cache key helpers
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
end

# === Application-level Caching Strategies ===

# 1. Database Query Caching
ActiveSupport.on_load(:active_record) do
  # Enable query caching for expensive operations
  class ApplicationRecord
    # Cache expensive counts
    def self.cached_count(expires_in: 5.minutes)
      Rails.cache.fetch("#{table_name}_count", expires_in: expires_in) do
        count
      end
    end
    
    # Cache expensive calculations
    def cached_association_count(association, expires_in: 5.minutes)
      Rails.cache.fetch("#{self.class.table_name}:#{id}:#{association}_count", expires_in: expires_in) do
        send(association).count
      end
    end
  end
end

# 2. Fragment Caching Configuration
ActionController::Base.class_eval do
  # Helper for conditional caching based on user state
  def cache_unless_signed_in(name = {}, options = {}, &block)
    if user_signed_in?
      yield
    else
      cache(name, options, &block)
    end
  end
  
  # Helper for user-specific caching
  def cache_for_user(name = {}, options = {}, &block)
    if user_signed_in?
      cache_key = Array(name) + ["user", current_user.id]
      cache(cache_key, options, &block)
    else
      cache(name, options, &block)
    end
  end
end

# 3. HTTP Caching Headers
class ApplicationController
  # Set cache headers for public pages
  def set_public_cache_headers(max_age: 300)
    expires_in max_age, public: true
    response.headers['Vary'] = 'Accept-Encoding'
  end
  
  # Set cache headers for private pages
  def set_private_cache_headers(max_age: 60)
    expires_in max_age, private: true
    response.headers['Vary'] = 'Accept-Encoding, Cookie'
  end
  
  # Prevent caching
  def prevent_caching
    response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'
    response.headers['Pragma'] = 'no-cache'
    response.headers['Expires'] = '0'
  end
end

# 4. Russian Doll Caching for nested resources
module RussianDollCaching
  extend ActiveSupport::Concern
  
  included do
    # Touch parent records when child is updated
    belongs_to :parent, touch: true if respond_to?(:belongs_to)
  end
  
  # Generate nested cache key
  def nested_cache_key
    [self.class.model_name.cache_key, id, updated_at.to_i].join('/')
  end
end

# === Cloudflare Configuration ===
# Add this to your Cloudflare Page Rules or use Workers for more control

CLOUDFLARE_CONFIG = {
  # Page Rules Configuration
  page_rules: [
    {
      url: "streetwatch.com/films/*",
      settings: {
        cache_level: "cache_everything",
        edge_cache_ttl: 3600, # 1 hour
        browser_cache_ttl: 600, # 10 minutes
        bypass_cache_on_cookie: "streetwatch_session|remember_user_token"
      }
    },
    {
      url: "streetwatch.com/users/*",
      settings: {
        cache_level: "cache_everything",
        edge_cache_ttl: 1800, # 30 minutes
        browser_cache_ttl: 300, # 5 minutes
        bypass_cache_on_cookie: "streetwatch_session|remember_user_token"
      }
    },
    {
      url: "streetwatch.com/api/*",
      settings: {
        cache_level: "bypass",
        browser_cache_ttl: 0
      }
    },
    {
      url: "streetwatch.com/admin/*",
      settings: {
        cache_level: "bypass",
        browser_cache_ttl: 0,
        security_level: "high"
      }
    },
    {
      url: "streetwatch.com/assets/*",
      settings: {
        cache_level: "cache_everything",
        edge_cache_ttl: 2592000, # 30 days
        browser_cache_ttl: 604800 # 7 days
      }
    }
  ],
  
  # Transform Rules for logged-in users
  transform_rules: {
    # Add cache key for user segments
    cache_key: {
      include_cookie: ["streetwatch_session"],
      include_query_string: ["page", "filter", "sort", "query"]
    }
  },
  
  # Worker script for advanced caching
  worker_script: <<~JS
    addEventListener('fetch', event => {
      event.respondWith(handleRequest(event.request))
    })
    
    async function handleRequest(request) {
      const url = new URL(request.url)
      
      // Check if user is logged in
      const cookie = request.headers.get('Cookie')
      const isLoggedIn = cookie && (
        cookie.includes('streetwatch_session') || 
        cookie.includes('remember_user_token')
      )
      
      // Different cache strategies based on authentication
      let cacheTime = 0
      
      if (!isLoggedIn) {
        // Aggressive caching for anonymous users
        if (url.pathname.startsWith('/films')) {
          cacheTime = 3600 // 1 hour
        } else if (url.pathname.startsWith('/users')) {
          cacheTime = 1800 // 30 minutes
        } else if (url.pathname === '/') {
          cacheTime = 600 // 10 minutes
        }
      } else {
        // Lighter caching for logged-in users
        if (url.pathname.startsWith('/films') && !url.pathname.includes('/edit')) {
          cacheTime = 300 // 5 minutes
        } else if (url.pathname.startsWith('/users') && !url.pathname.includes('/settings')) {
          cacheTime = 180 // 3 minutes
        }
      }
      
      // Check cache if applicable
      if (cacheTime > 0) {
        const cache = caches.default
        const cacheKey = new Request(request.url, request)
        
        // Try to get from cache
        let response = await cache.match(cacheKey)
        
        if (!response) {
          // Not in cache, fetch from origin
          response = await fetch(request)
          
          // Clone response for caching
          const responseToCache = response.clone()
          
          // Add cache headers
          const headers = new Headers(responseToCache.headers)
          headers.set('Cache-Control', `public, max-age=${cacheTime}`)
          
          // Store in cache
          const cachedResponse = new Response(responseToCache.body, {
            status: responseToCache.status,
            statusText: responseToCache.statusText,
            headers: headers
          })
          
          event.waitUntil(cache.put(cacheKey, cachedResponse))
        }
        
        return response
      }
      
      // No caching, fetch directly
      return fetch(request)
    }
  JS
}

# === Cache Warming Strategy ===
module CacheWarming
  class Warmer
    def self.warm_popular_content
      # Warm popular films
      Film.published
          .order(views_count: :desc)
          .limit(50)
          .each do |film|
        Rails.cache.fetch("film:#{film.id}:full", expires_in: 1.hour) do
          film.as_json(include: [:user, :film_riders, :film_filmers])
        end
      end
      
      # Warm active users
      User.active
          .where('last_sign_in_at > ?', 7.days.ago)
          .limit(100)
          .each do |user|
        Rails.cache.fetch("user:#{user.id}:profile", expires_in: 30.minutes) do
          {
            user: user.as_json,
            films_count: user.films.published.count,
            photos_count: user.photos.published.count,
            followers_count: user.followers.count
          }
        end
      end
    end
  end
end

# Schedule cache warming (add to whenever gem or sidekiq-cron)
# every 30.minutes do
#   CacheWarming::Warmer.warm_popular_content
# end
