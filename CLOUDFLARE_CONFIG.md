# CloudFlare Configuration for StreetWatch.mov

## Required CloudFlare Settings for Session/Login to Work

### 1. SSL/TLS Settings
**Location:** SSL/TLS → Overview

- **Encryption mode:** Must be set to **"Full"** or **"Full (strict)"**
  - ❌ NOT "Flexible" - this will break sessions and logins
  - ✅ "Full" or "Full (strict)" required

### 2. Caching Rules
**Location:** Caching → Configuration

You need to create rules to **bypass cache** for dynamic pages:

**Rule 1: Bypass cache for auth pages**
**When incoming requests match:**
- URL Path contains `/users/sign_in`
- OR URL Path contains `/users/sign_up`
- OR URL Path contains `/users/password`
- OR URL Path contains `/users/sign_out`

**Then:**
- Cache level: **Bypass**

**Rule 2: Bypass cache for admin dashboard**
**When incoming requests match:**
- URL Path starts with `/admin`

**Then:**
- Cache level: **Bypass**

**IMPORTANT:** Your Films, Photos, and Users pages should NOT be cached with 30-minute TTLs. These are dynamic pages that change frequently. Set them to Bypass or 0 seconds.

### 3. Page Rules (Alternative to Caching Rules)
**Location:** Rules → Page Rules

Create a page rule:
- **URL:** `streetwatch.mov/users/*`
- **Settings:**
  - Cache Level: Bypass
  - Disable Performance

### 4. Security Settings
**Location:** Security → Settings

- **Always Use HTTPS:** ✅ ON
- **Automatic HTTPS Rewrites:** ✅ ON
- **Browser Integrity Check:** Can be ✅ ON or ❌ OFF (try OFF if issues persist)

### 5. Network Settings
**Location:** Network

- **HTTP/2:** ✅ ON
- **HTTP/3 (with QUIC):** ✅ ON (recommended)
- **WebSockets:** ✅ ON

### 6. DNS Settings
**Location:** DNS → Records

Your A record for `streetwatch.mov` should be:
- **Type:** A
- **Name:** @ (or streetwatch.mov)
- **IPv4 address:** Your Railway IP
- **Proxy status:** 🟠 **Proxied** (orange cloud)
- **TTL:** Auto

## Troubleshooting

If login still doesn't work after these settings:

1. **Clear CloudFlare cache:**
   - Go to Caching → Configuration
   - Click "Purge Everything"

2. **Try with CloudFlare temporarily disabled:**
   - In DNS settings, click the orange cloud to make it gray (not proxied)
   - Test if login works
   - If it works, the issue is a CloudFlare setting above
   - Re-enable proxy (orange cloud) after testing

3. **Check Browser Console:**
   - Look for Set-Cookie headers in Network tab
   - Check if `_streetwatch_session` cookie is being set

4. **Test in Incognito Mode:**
   - Browser extensions can block cookies
   - Incognito mode will rule out extension issues

## Current Status
- SSL/TLS Mode: **[NEEDS TO BE VERIFIED]**
- Caching Rules: **[NEEDS TO BE CREATED]**
- Page Rules: **[NEEDS TO BE CREATED]**
