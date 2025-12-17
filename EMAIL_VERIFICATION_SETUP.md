# Email Verification Setup

This document explains the email verification system that has been implemented for Streetwatch.

## Overview

Email verification is now **required for all new user signups** to prevent fake email addresses. However, **admin-created placeholder accounts bypass this requirement** and can use any email address.

## How It Works

### For Regular User Signups

1. User fills out the registration form at `/users/sign_up`
2. Upon submission, the user receives a confirmation email at the provided address
3. User must click the confirmation link in the email to activate their account
4. Until confirmed, the user cannot log in
5. Users can resend the confirmation email from `/users/confirmation/new`

### For Admin-Created Accounts

1. Admin creates a user profile from the admin panel (`/admin/users`)
2. When the "Admin created" checkbox is checked, email verification is **automatically skipped**
3. The account is immediately active and ready to be claimed
4. These accounts can use fake/placeholder emails (e.g., `placeholder@example.com`)

### For Google OAuth Signups

1. Users who sign up via "Sign in with Google" are **automatically confirmed**
2. Google has already verified their email, so no additional verification is needed

## Database Changes

The migration adds these fields to the `users` table:

- `confirmation_token` - Unique token sent in confirmation emails
- `confirmed_at` - Timestamp when the email was confirmed
- `confirmation_sent_at` - When the confirmation email was sent
- `unconfirmed_email` - Stores new email during email change process

**Important:** All existing users are automatically confirmed during migration, so they won't be locked out.

## Email Configuration

### Current Setup

- **From address:** `streetwatchmov@gmail.com` (configured in both Devise and ApplicationMailer)
- **Development:** Emails display in console/logs (not actually sent)
- **Production:** Requires SMTP configuration (see below)

### Production Email Setup Required

To send actual confirmation emails in production, you need to configure SMTP settings in `config/environments/production.rb`:

```ruby
config.action_mailer.default_url_options = { host: "yourdomain.com" }
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  user_name: Rails.application.credentials.dig(:smtp, :user_name),
  password: Rails.application.credentials.dig(:smtp, :password),
  address: "smtp.gmail.com",
  port: 587,
  authentication: :plain,
  enable_starttls_auto: true
}
```

#### Option 1: Gmail SMTP (Recommended for streetwatchmov@gmail.com)

1. Go to your Google Account settings
2. Enable 2-factor authentication
3. Generate an "App Password" for mail
4. Add credentials using Rails encrypted credentials:

```bash
EDITOR="code --wait" rails credentials:edit
```

Add:
```yaml
smtp:
  user_name: streetwatchmov@gmail.com
  password: your-app-password-here
```

#### Option 2: SendGrid, Mailgun, or AWS SES

For production apps, consider using a transactional email service:
- **SendGrid:** Free tier includes 100 emails/day
- **Mailgun:** Free tier includes 5,000 emails/month
- **AWS SES:** $0.10 per 1,000 emails

## Running the Migration

To apply these changes to your database:

```bash
cd "/Volumes/Dropbox Mac/Dropbox/SRV/STREETWATCH SITE/STREETWATCH"
rails db:migrate
```

## Testing the Flow

### Test Regular Signup with Email Verification

1. Start your Rails server
2. Visit `/users/sign_up`
3. Fill out the form with a real email address you can access
4. Submit the form
5. Check your email (or console in development) for the confirmation link
6. Click the confirmation link
7. You should now be able to log in

### Test Admin Bypass

1. Log in as an admin
2. Visit `/admin/users/new`
3. Fill out the form with any email (e.g., `fake@example.com`)
4. **Check the "Admin created" checkbox**
5. Submit the form
6. The account is immediately active (no email verification required)

### Test Resending Confirmation

1. If a user didn't receive their confirmation email, they can visit `/users/confirmation/new`
2. Enter their email address
3. A new confirmation email will be sent

## Code Changes Summary

### Files Modified

1. **[app/models/user.rb](app/models/user.rb)**
   - Added `:confirmable` to Devise modules
   - Added `skip_confirmation_for_admin_created` callback
   - Auto-confirm Google OAuth users

2. **[config/initializers/devise.rb](config/initializers/devise.rb)**
   - Updated `mailer_sender` to `streetwatchmov@gmail.com`

3. **[app/mailers/application_mailer.rb](app/mailers/application_mailer.rb)**
   - Updated default `from` to `streetwatchmov@gmail.com`

### Files Created

4. **[db/migrate/20251217000001_add_confirmable_to_users.rb](db/migrate/20251217000001_add_confirmable_to_users.rb)**
   - Adds confirmation fields to users table
   - Auto-confirms existing users

## User Experience

### What Users Will See

**After Signing Up:**
> "A message with a confirmation link has been sent to your email address. Please follow the link to activate your account."

**If They Try to Login Before Confirming:**
> "You have to confirm your email address before continuing."

**After Clicking Confirmation Link:**
> "Your email address has been successfully confirmed."

**If Confirmation Link Expires:**
Users can request a new confirmation email at `/users/confirmation/new`

## Admin Panel Notes

The admin panel already has an "Admin created" checkbox that was being used for the claim token feature. This same checkbox now also:
- Skips email verification for that account
- Allows fake/placeholder emails to be used

No changes to the admin panel UI are needed - it already works correctly!

## Troubleshooting

### Emails Not Sending in Development

By default, emails are logged to the console in development. Check your Rails server logs for the confirmation link.

### Emails Not Sending in Production

1. Check your SMTP credentials are correct
2. Verify the SMTP port and address are correct
3. Check your email provider's sending limits
4. Look in `log/production.log` for error messages

### User Can't Find Confirmation Email

1. Check spam/junk folder
2. Verify the email address was typed correctly
3. Resend confirmation email from `/users/confirmation/new`

### Admin-Created Account Still Requires Confirmation

Make sure the "Admin created" checkbox was checked when creating the user. You can verify by checking if `admin_created` is `true` in the database.

## Security Notes

- Confirmation tokens are stored hashed in the database
- Tokens are unique and generated using `SecureRandom`
- Admin-created accounts should only be used for legitimate placeholder profiles
- The claim token system provides a secure way for users to take ownership of admin-created profiles
