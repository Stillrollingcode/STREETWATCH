# AWS S3 Setup for File Storage

This guide will help you set up Amazon S3 for persistent file storage in production, preventing loss of uploaded videos and images during redeployments.

## Why Use S3?

When using local disk storage (`config.active_storage.service = :local`), files are stored in the `storage/` directory on your server. Every time you redeploy, this directory can be wiped or replaced, causing you to lose all uploaded content.

S3 provides:
- **Persistent storage** across deployments
- **Scalability** for large video files
- **CDN integration** for faster delivery
- **Backup and versioning** options

## Step 1: Create an AWS Account

1. Go to [aws.amazon.com](https://aws.amazon.com) and create an account
2. Complete the signup process

## Step 2: Create an S3 Bucket

1. Log into AWS Console
2. Navigate to S3 service
3. Click "Create bucket"
4. Choose a bucket name (must be globally unique):
   - Example: `streetwatch-production`
   - Or: `your-app-name-production`
5. Select your preferred region (e.g., `us-east-1`)
6. **Block Public Access settings:**
   - Keep "Block all public access" **CHECKED**
   - Rails Active Storage will handle access via signed URLs
7. Enable versioning (optional but recommended)
8. Click "Create bucket"

## Step 3: Create IAM User with S3 Access

1. Navigate to IAM service in AWS Console
2. Click "Users" → "Create user"
3. Username: `streetwatch-s3-user` (or similar)
4. Click "Next"
5. Select "Attach policies directly"
6. Search for and select `AmazonS3FullAccess` (or create a custom policy for specific bucket)
7. Click "Next" → "Create user"

### Create Access Keys

1. Click on the newly created user
2. Go to "Security credentials" tab
3. Scroll to "Access keys"
4. Click "Create access key"
5. Select use case: "Application running outside AWS"
6. Click "Next" → "Create access key"
7. **IMPORTANT:** Save both:
   - Access key ID (e.g., `AKIAIOSFODNN7EXAMPLE`)
   - Secret access key (e.g., `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`)
   - You won't be able to see the secret key again!

## Step 4: Configure Rails Credentials

### Option A: Using Rails Encrypted Credentials (Recommended)

```bash
# Edit credentials
EDITOR="nano" rails credentials:edit

# Add AWS credentials:
aws:
  access_key_id: YOUR_ACCESS_KEY_ID
  secret_access_key: YOUR_SECRET_ACCESS_KEY
```

Save and close the editor (Ctrl+X, then Y, then Enter for nano).

### Option B: Using Environment Variables

Set these environment variables on your production server:

```bash
export AWS_REGION=us-east-1
export AWS_BUCKET=streetwatch-production
```

And update `config/storage.yml` to use ENV vars for credentials:

```yaml
amazon:
  service: S3
  access_key_id: <%= ENV['AWS_ACCESS_KEY_ID'] %>
  secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
  region: <%= ENV.fetch("AWS_REGION", "us-east-1") %>
  bucket: <%= ENV.fetch("AWS_BUCKET") { "streetwatch-#{Rails.env}" } %>
```

## Step 5: Install AWS SDK Gem

Already configured in your Gemfile. Just run:

```bash
bundle install
```

## Step 6: Deploy Changes

1. Commit your changes:
```bash
git add .
git commit -m "Configure AWS S3 for Active Storage"
git push
```

2. Deploy to production (method depends on your hosting):
```bash
# If using Kamal:
kamal deploy

# Or SSH and pull changes:
ssh your-server
cd /path/to/app
git pull
bundle install
rails assets:precompile
# Restart your Rails server
```

## Step 7: Set Environment Variables (if using Option B)

On your production server or hosting platform, set:

```bash
AWS_ACCESS_KEY_ID=your_access_key_id
AWS_SECRET_ACCESS_KEY=your_secret_access_key
AWS_REGION=us-east-1
AWS_BUCKET=streetwatch-production
```

### For different hosting platforms:

**Heroku:**
```bash
heroku config:set AWS_ACCESS_KEY_ID=your_key
heroku config:set AWS_SECRET_ACCESS_KEY=your_secret
heroku config:set AWS_REGION=us-east-1
heroku config:set AWS_BUCKET=streetwatch-production
```

**Railway:**
Add in the Variables tab of your project

**Digital Ocean App Platform:**
Add in the Environment Variables section

## Step 8: Migrate Existing Files (Optional)

If you have existing files in local storage that you want to keep:

```ruby
# In Rails console on production
Film.find_each do |film|
  if film.video.attached? && film.video.service_name == :local
    film.video.open do |file|
      film.video.attach(io: file, filename: film.video.filename)
    end
  end

  # For thumbnails
  if film.thumbnail.attached? && film.thumbnail.service_name == :local
    film.thumbnail.open do |file|
      film.thumbnail.attach(io: file, filename: film.thumbnail.filename)
    end
  end

  # For quality versions
  %w[video_4k video_2k video_1080p video_720p video_480p video_360p].each do |quality|
    attachment = film.send(quality)
    if attachment.attached? && attachment.service_name == :local
      attachment.open do |file|
        film.send(quality).attach(io: file, filename: attachment.filename)
      end
    end
  end
end
```

## Step 9: Test Upload

1. Upload a test video or image
2. Verify it appears correctly
3. Redeploy your application
4. Verify the file is still accessible

## Troubleshooting

### Files not uploading
- Check AWS credentials are correct
- Verify bucket name matches configuration
- Check IAM user has S3 permissions

### Files not accessible
- Ensure bucket region matches config
- Check Rails logs for errors
- Verify Active Storage routes are working

### Permission denied errors
- Verify IAM policy includes `s3:PutObject`, `s3:GetObject`, `s3:DeleteObject`
- Check bucket CORS settings if accessing from browser

## Cost Considerations

S3 pricing (as of 2024):
- Storage: ~$0.023 per GB/month
- Requests: Minimal cost for typical usage
- Data transfer: Free incoming, outgoing varies by region

Example monthly costs:
- 100GB of videos: ~$2.30/month
- 500GB of videos: ~$11.50/month
- 1TB of videos: ~$23/month

## Security Best Practices

1. **Never commit AWS credentials to Git**
2. Use Rails encrypted credentials or environment variables
3. Enable bucket versioning for backup
4. Set up CloudWatch alerts for unusual activity
5. Regularly rotate access keys
6. Use least-privilege IAM policies

## Alternative: Keep Local Storage (Not Recommended)

If you absolutely must use local storage in production:

1. Create a persistent volume/directory outside your app directory
2. Update `config/storage.yml`:
   ```yaml
   local:
     service: Disk
     root: /var/www/persistent_storage  # Outside app directory
   ```
3. Ensure this directory is excluded from deployment overwrites
4. Set up regular backups

**Warning:** This approach is fragile and not recommended for production.
