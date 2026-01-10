# Cloudflare Setup for StreetWatch

This guide walks you through configuring Cloudflare to maximize caching performance for your StreetWatch site.

## Prerequisites

- ✅ Domain pointing to Cloudflare nameservers
- ✅ Cloudflare account with your domain added
- ✅ SSL/TLS configured (Full or Full Strict mode)

## Step-by-Step Configuration

### 1. SSL/TLS Settings

**Go to**: SSL/TLS → Overview

```
Encryption mode: Full (strict)
```

**Why**: Ensures encrypted connection between Cloudflare and Railway

---

### 2. Page Rules Configuration

**Go to**: Rules → Page Rules

Create the following page rules **in this exact order** (order matters!):

#### Rule 1: Admin Pages (Bypass Cache)

```
URL Pattern: *streetwatch.com/admin/*

Settings:
├─ Cache Level: Bypass
├─ Security Level: High
└─ Disable Apps
```

**Why**: Admin pages should never be cached and need higher security

---

#### Rule 2: API Endpoints (Bypass Cache)

```
URL Pattern: *streetwatch.com/api/*

Settings:
├─ Cache Level: Bypass
└─ Browser Cache TTL: 0
```

**Why**: API responses are dynamic and shouldn't be cached

---

#### Rule 3: Films Pages (Aggressive Caching)

```
URL Pattern: *streetwatch.com/films*

Settings:
├─ Cache Level: Cache Everything
├─ Edge Cache TTL: 1 hour
├─ Browser Cache TTL: 10 minutes
└─ Bypass Cache on Cookie: streetwatch_session|remember_user_token
```

**Why**: Films are mostly static content, safe to cache aggressively for logged-out users

---

#### Rule 4: User Profile Pages

```
URL Pattern: *streetwatch.com/users/*

Settings:
├─ Cache Level: Cache Everything
├─ Edge Cache TTL: 30 minutes
├─ Browser Cache TTL: 5 minutes
└─ Bypass Cache on Cookie: streetwatch_session|remember_user_token
```

**Why**: User profiles change less frequently than films, medium caching

---

#### Rule 5: Static Assets (Maximum Caching)

```
URL Pattern: *streetwatch.com/assets/*

Settings:
├─ Cache Level: Cache Everything
├─ Edge Cache TTL: 30 days
└─ Browser Cache TTL: 7 days
```

**Why**: Assets are fingerprinted and immutable, can be cached indefinitely

---

### 3. Caching Configuration

**Go to**: Caching → Configuration

```
Caching Level: Standard
Browser Cache TTL: Respect Existing Headers
```

**Why**: Let Rails control cache timing via headers we set in controllers

---

### 4. Speed → Optimization Settings

**Go to**: Speed → Optimization

Enable these optimizations:

```
✅ Auto Minify
   ├─ JavaScript
   ├─ CSS
   └─ HTML

✅ Brotli

✅ Early Hints

✅ Rocket Loader™ (Optional - test first)
```

**Why**: Reduces payload size and improves load times

---

### 5. Network Settings

**Go to**: Network

```
✅ HTTP/2
✅ HTTP/3 (with QUIC)
✅ 0-RTT Connection Resumption
✅ WebSockets
```

**Why**: Modern protocols for faster connections

---

### 6. Custom Cache Keys (Pro/Business Plan)

**Go to**: Caching → Configuration → Custom Cache Key

If you have a paid plan, configure:

```
Query String:
├─ Include: page, q, sort, filter, film_type, group_by
└─ Exclude: utm_*, fbclid, gclid

Headers:
└─ Cookie: Check for session cookies

User:
└─ Include: Device Type, Country
```

**Why**: Better cache segmentation for different users/queries

---

## Verifying Configuration

### 1. Check Cache Status

```bash
# Check if page is being cached
curl -I https://streetwatch.com/films

# Look for these headers:
# cf-cache-status: HIT (cached)
# cf-cache-status: MISS (not cached yet)
# cf-cache-status: DYNAMIC (bypass cache)
# cf-cache-status: EXPIRED (needs refresh)
```

### 2. Test Different Pages

```bash
# Films page (should HIT after first request)
curl -I https://streetwatch.com/films
curl -I https://streetwatch.com/films  # Second request should HIT

# Admin page (should be DYNAMIC/BYPASS)
curl -I https://streetwatch.com/admin
# cf-cache-status: DYNAMIC

# Assets (should HIT immediately)
curl -I https://streetwatch.com/assets/application-FINGERPRINT.css
# cf-cache-status: HIT
```

### 3. Monitor in Cloudflare Dashboard

**Go to**: Analytics → Performance

Monitor:
- **Cache Hit Rate**: Target >80%
- **Bandwidth Saved**: Should increase over time
- **Origin Requests**: Should decrease as cache warms up

---

## Cache Purge Strategies

### Purge Everything

**Go to**: Caching → Configuration → Purge Cache

Use when deploying major changes

### Purge by URL

```bash
# Purge specific film page
Purge Single File: https://streetwatch.com/films/film-slug

# Or use Cloudflare API
curl -X POST "https://api.cloudflare.com/client/v4/zones/ZONE_ID/purge_cache" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"files":["https://streetwatch.com/films/specific-film"]}'
```

### Automatic Purge on Deploy (Optional)

Add to your Railway deployment script:

```bash
# In package.json or deployment script
"scripts": {
  "deploy": "git push railway main && curl -X POST 'https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/purge_cache' -H 'Authorization: Bearer $CF_API_TOKEN' -H 'Content-Type: application/json' --data '{\"purge_everything\":true}'"
}
```

---

## Expected Performance Improvements

### Before Cloudflare Caching

```
Films Index Page:
├─ Time to First Byte (TTFB): 300-500ms
├─ Total Load Time: 800-1200ms
└─ Origin Server Load: 100%
```

### After Cloudflare Caching

```
Films Index Page (Cached):
├─ Time to First Byte (TTFB): 50-100ms  (80% faster)
├─ Total Load Time: 200-400ms  (75% faster)
└─ Origin Server Load: 20%  (80% reduction)
```

---

## Troubleshooting

### Cache Not Working

**Problem**: `cf-cache-status: BYPASS` or `DYNAMIC` on all requests

**Solutions**:
1. Check Page Rules are in correct order
2. Verify "Cache Level: Cache Everything" is set
3. Ensure SSL/TLS is "Full (strict)"
4. Check that URLs match page rule patterns exactly

### Logged-in Users Seeing Cached Content

**Problem**: Personalized content being cached

**Solution**:
- Verify "Bypass Cache on Cookie" includes `streetwatch_session`
- Check that Rails is setting session cookies correctly

### Stale Content

**Problem**: Updates not appearing immediately

**Solution**:
- This is expected behavior with caching!
- Cache will expire after Edge Cache TTL
- Manually purge specific URLs when needed
- Consider using Cache Tags API (Business plan) for selective purging

---

## Advanced: Cache Tags (Business Plan Feature)

If you have Cloudflare Business plan, use Cache Tags for granular control:

```ruby
# In controllers
response.headers['Cache-Tag'] = "film-#{@film.id}"

# Then purge by tag when film updates
# Film.after_save callback:
CloudflareService.purge_cache_tag("film-#{self.id}")
```

---

## Cost & Plan Recommendations

### Free Plan
- ✅ Sufficient for most needs
- ✅ 3 Page Rules included
- ✅ Basic caching works great
- ❌ No Cache Tags or advanced features

### Pro Plan ($25/month)
- ✅ 20 Page Rules
- ✅ Better DDoS protection
- ✅ WAF (Web Application Firewall)
- ❌ Still no Cache Tags

### Business Plan ($250/month)
- ✅ 50 Page Rules
- ✅ Cache Tags API
- ✅ Advanced security features
- ✅ Recommended for production apps

**Recommendation for StreetWatch**: Start with **Free plan**, upgrade to Pro if you need more page rules or security features.

---

## Monitoring & Alerts

### Set Up Alerts

**Go to**: Notifications → Add

Recommended alerts:
```
├─ Origin Error Rate Above 5%
├─ Cache Hit Rate Below 70%
└─ SSL Certificate Expiring Soon
```

### Check Performance Regularly

```bash
# Weekly check
1. Review Analytics → Performance
2. Check Cache Hit Rate trend
3. Monitor Bandwidth Saved
4. Review Top URLs by traffic
```

---

## Next Steps

After configuring Cloudflare:

1. ✅ Test all page rules with curl commands above
2. ✅ Monitor cache hit rate for 24 hours
3. ✅ Verify logged-in users don't see cached content
4. ✅ Document any custom purge workflows for your team

## Additional Resources

- Cloudflare Page Rules Docs: https://developers.cloudflare.com/rules/page-rules/
- Cache Headers Guide: https://developers.cloudflare.com/cache/concepts/cache-control/
- Cloudflare API: https://developers.cloudflare.com/api/

---

**Questions?** Check the [PERFORMANCE_OPTIMIZATIONS.md](PERFORMANCE_OPTIMIZATIONS.md:1) for related caching configurations in Rails.
