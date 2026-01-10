# Redis Setup for StreetWatch

## Local Development (Optional)

### Installing Redis on macOS

```bash
# Using Homebrew
brew install redis

# Start Redis
brew services start redis

# Verify it's running
redis-cli ping
# Should return: PONG
```

### Configuration for Development

Add to your `.env` file (or `.env.development`):

```bash
# Development Redis (optional - falls back to memory store if not set)
REDIS_URL=redis://localhost:6379/1
```

## Production Setup (Railway)

### Option 1: Railway Redis Plugin (Recommended)

1. **Go to your Railway project**
   - Navigate to: https://railway.app/project/YOUR_PROJECT_ID

2. **Add Redis Plugin**
   - Click "+ New" button
   - Select "Database" → "Add Redis"
   - Railway will automatically provision Redis and add `REDIS_URL` to your environment

3. **Verify Environment Variable**
   - Go to your service → "Variables" tab
   - You should see `REDIS_URL` automatically configured
   - Format: `redis://default:PASSWORD@HOST:PORT`

### Option 2: External Redis Provider

If you prefer an external Redis provider:

#### Upstash (Free tier available)

1. **Create account**: https://upstash.com/
2. **Create Redis database**
   - Select region closest to your Railway deployment
   - Copy the connection URL
3. **Add to Railway**:
   ```
   REDIS_URL=redis://default:PASSWORD@HOST:PORT
   ```

#### Redis Cloud (Free tier available)

1. **Create account**: https://redis.com/try-free/
2. **Create database**
3. **Copy connection string**
4. **Add to Railway environment variables**

## Verifying Redis Connection

### Test in Rails Console

```bash
# Start Rails console
bin/rails console

# Test Redis connection
Rails.cache.write('test_key', 'Hello Redis!')
# => true

Rails.cache.read('test_key')
# => "Hello Redis!"

Rails.cache.delete('test_key')
# => true

# Check cache store type
Rails.cache.class
# => ActiveSupport::Cache::RedisCacheStore (if Redis configured)
# => ActiveSupport::Cache::MemoryStore (if Redis not available)
```

### Check Redis Stats

```bash
# In Rails console
Rails.cache.stats
# Shows hit/miss rates and other metrics
```

## Configuration Details

The caching initializer ([config/initializers/caching.rb](config/initializers/caching.rb:1)) automatically:

- ✅ Uses Redis if `REDIS_URL` is set
- ✅ Falls back to memory store if Redis isn't available
- ✅ Configures compression for values > 1KB
- ✅ Sets up error handling to prevent cache failures from breaking the app

## Performance Benefits

With Redis configured:

- **Faster page loads**: Cached pages served in <50ms
- **Reduced database load**: Frequently accessed data cached
- **Better scalability**: Multiple app instances share the same cache
- **Persistent caching**: Cache survives app restarts

## Monitoring Redis

### Railway Dashboard

If using Railway Redis plugin:
- View metrics in Railway dashboard
- Monitor memory usage
- Check connection count

### Redis CLI Commands

```bash
# Connect to Redis
redis-cli -u $REDIS_URL

# Check memory usage
INFO memory

# See all keys
KEYS *

# Get cache statistics
INFO stats

# Monitor commands in real-time
MONITOR
```

## Troubleshooting

### Cache not working

```bash
# Clear the cache
bin/rails cache:clear

# Or in Rails console
Rails.cache.clear
```

### Connection errors

Check that:
1. `REDIS_URL` is correctly formatted
2. Redis server is running
3. Firewall allows connection
4. Network allows outbound connections to Redis host

### Memory issues

```bash
# Check current memory usage
redis-cli -u $REDIS_URL INFO memory

# Clear all keys (careful in production!)
redis-cli -u $REDIS_URL FLUSHDB
```

## Cost Estimates

### Railway Redis Plugin
- Free tier: Included in Railway's free tier
- Pro tier: ~$5/month for 256MB

### Upstash
- Free tier: 10,000 commands/day, 256MB
- Pay-as-you-go: $0.20 per 100K commands

### Redis Cloud
- Free tier: 30MB
- Paid plans: Starting at $7/month for 100MB

## Recommended Configuration

For StreetWatch production deployment:

```bash
# Railway environment variables
REDIS_URL=redis://default:PASSWORD@HOST:PORT  # Auto-set by Railway
RAILS_MAX_THREADS=5  # Matches Redis pool size
```

The app will automatically use Redis when `REDIS_URL` is set, with no code changes required!

## Next Steps

After setting up Redis:
1. ✅ Deploy to Railway
2. ✅ Verify Redis connection in production logs
3. ✅ Monitor cache hit rates
4. ✅ Configure Cloudflare caching (see [CLOUDFLARE_SETUP.md](CLOUDFLARE_SETUP.md:1))
