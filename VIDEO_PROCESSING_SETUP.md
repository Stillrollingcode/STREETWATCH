# Video Processing Setup for Production

## Overview
The application now processes videos in the background to generate thumbnails and multiple quality versions (4K, 2K, 1080p, 720p, 480p, 360p). This prevents timeouts and improves user experience.

## Requirements for Production

### 1. FFmpeg Installation
FFmpeg must be installed on the production server for video processing.

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y ffmpeg
```

**macOS (for local testing):**
```bash
brew install ffmpeg
```

**Verify installation:**
```bash
ffmpeg -version
```

### 2. Background Job Processing
The application uses ActiveJob with the default async adapter. For production, you should configure a proper job queue.

#### Option A: Solid Queue (Recommended for Rails 7.1+)
Add to Gemfile:
```ruby
gem 'solid_queue'
```

Then run:
```bash
bundle install
rails solid_queue:install
rails db:migrate
```

Update `config/environments/production.rb`:
```ruby
config.active_job.queue_adapter = :solid_queue
```

Start the worker in production:
```bash
bin/jobs
```

#### Option B: Sidekiq (Alternative)
Add to Gemfile:
```ruby
gem 'sidekiq'
gem 'redis'
```

Update `config/environments/production.rb`:
```ruby
config.active_job.queue_adapter = :sidekiq
```

Start Sidekiq:
```bash
bundle exec sidekiq
```

### 3. Storage Configuration
Ensure your production storage has enough space for:
- Original videos
- Up to 6 transcoded versions (4K, 2K, 1080p, 720p, 480p, 360p)
- Thumbnails

**Storage Estimates (per video):**
- 4K (2160p): ~15-25GB per hour
- 2K (1440p): ~8-12GB per hour
- 1080p: ~4-6GB per hour
- 720p: ~2-3GB per hour
- 480p: ~800MB-1.2GB per hour
- 360p: ~400-600MB per hour

Consider using cloud storage (S3, GCS) for production:

**config/storage.yml** (example for S3):
```yaml
amazon:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: us-east-1
  bucket: your-bucket-name
```

**config/environments/production.rb**:
```ruby
config.active_storage.service = :amazon
```

### 4. Temporary Directory
Ensure `/tmp` has sufficient space for video processing:
- Videos are temporarily stored during processing
- Thumbnails are generated here
- Transcoded files are created here

### 5. Memory Considerations
Video transcoding is memory-intensive. Ensure your production server has:
- **Minimum:** 4GB RAM (for 1080p and below)
- **Recommended:** 8GB+ RAM for 2K/4K video processing
- **Optimal:** 16GB+ RAM for 4K transcoding with multiple concurrent jobs

### 6. Process Monitoring
Add process monitoring to ensure background jobs are running:

**With systemd** (example):
```ini
[Unit]
Description=Rails Background Jobs
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/var/www/streetwatch
ExecStart=/usr/bin/bundle exec bin/jobs
Restart=always

[Install]
WantedBy=multi-user.target
```

## Deployment Checklist

- [ ] FFmpeg installed and accessible
- [ ] Background job processor configured
- [ ] Background job processor running
- [ ] Sufficient storage space allocated
- [ ] Temp directory writable and has space
- [ ] Process monitoring configured
- [ ] Logs configured to capture video processing errors

## Testing Production Setup

After deployment, test the video processing:

1. Upload a test video through the UI
2. Check logs for processing job:
```bash
tail -f log/production.log | grep "ProcessVideoJob"
```

3. Verify outputs:
   - Thumbnail should appear after ~30 seconds
   - Quality versions should be available within a few minutes
   - Check storage directory for generated files

## Troubleshooting

### Thumbnails Not Generating
- Check if FFmpeg is installed: `which ffmpeg`
- Check job processor is running: `ps aux | grep jobs`
- Check logs: `tail -f log/production.log`
- Verify file permissions on `tmp/` directory

### Transcoding Failing
- Check available memory: `free -h`
- Check disk space: `df -h`
- Reduce quality options in `ProcessVideoJob` if needed
- Check FFmpeg errors in logs

### Jobs Not Running
- Verify job adapter configuration
- Check if background processor is running
- Restart background job processor
- Check for errors in job logs

## Performance Optimization

### Adjust Transcoding Presets
In `app/jobs/process_video_job.rb`, you can modify:
- `preset`: Change from 'medium' to 'fast' or 'ultrafast' for faster processing
- `crf`: Lower values = better quality but larger files (default: 23)
- Quality levels: Remove 4K/2K if not needed to save storage and processing time
- Bitrates: Adjust for your quality/filesize preferences
  - 4K: 20000k (default)
  - 2K: 10000k (default)
  - 1080p: 5000k (default)
  - 720p: 2500k (default)

### Prioritize Jobs
Configure job priorities in production:
```ruby
config.active_job.queue_priority = {
  default: 5,
  video_processing: 10
}
```

### Process Only on Upload
To skip processing for YouTube videos (which don't need transcoding):
- The job only runs if `video.attached?` is true
- YouTube URLs use direct embedding without processing
