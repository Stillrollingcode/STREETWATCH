# Video Features Setup

## What's Been Added

### 1. Video Upload & Storage
- Films can now have video files attached via Active Storage
- Supports all common video formats (MP4, MOV, AVI, etc.)
- Video upload field added to film form

### 2. Video.js Player
- Professional HTML5 video player integrated
- Responsive and mobile-friendly
- Custom styling matching the Streetwatch theme
- Shows thumbnail as poster before playback
- Full controls (play, pause, volume, fullscreen, etc.)

### 3. Automatic Thumbnail Generation
- Automatically generates thumbnail from uploaded video
- Takes screenshot at 10% into the video
- Only generates if no manual thumbnail is uploaded
- **Requires FFmpeg to be installed**

## Installation Requirements

### Install FFmpeg (Required for Thumbnail Generation)

FFmpeg is needed to automatically generate thumbnails from videos.

**On macOS (using Homebrew):**
```bash
brew install ffmpeg
```

**On Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install ffmpeg
```

**Verify installation:**
```bash
ffmpeg -version
```

### If You Don't Install FFmpeg
- Video upload and playback will still work perfectly
- You'll just need to manually upload thumbnails for each film
- The app will show a placeholder if no thumbnail is provided

## How to Use

### Adding a Film with Video

1. Go to `/films/new` (must be logged in)
2. Fill in the film details
3. Upload a video file (MP4 recommended)
4. Optionally upload a custom thumbnail
   - If you don't, one will be auto-generated from the video
5. Save the film

### Video Playback

- Navigate to any film show page
- If a video is attached, it will display in a professional video player
- Click play to watch
- Use the controls for volume, fullscreen, etc.

## Storage Considerations

### Development
- Videos are stored locally in `storage/` directory
- Good for testing, but not recommended for production

### Production
- **Recommended:** Use cloud storage (AWS S3, Google Cloud Storage)
- Videos can be large files (100MB - 2GB+)
- Cloud storage provides:
  - Better performance
  - CDN integration
  - Automatic backups
  - Cost-effective scaling

### Setting up S3 (Optional, for Production)

1. Uncomment in Gemfile:
```ruby
gem "aws-sdk-s3"
```

2. Run `bundle install`

3. Configure in `config/storage.yml`:
```yaml
amazon:
  service: S3
  access_key_id: <%= ENV['AWS_ACCESS_KEY_ID'] %>
  secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
  region: us-east-1
  bucket: your-bucket-name
```

4. Update `config/environments/production.rb`:
```ruby
config.active_storage.service = :amazon
```

## Technical Details

### Files Modified
- `app/models/film.rb` - Added video attachment and thumbnail generation
- `app/controllers/films_controller.rb` - Added video to permitted params
- `app/views/films/_form.html.erb` - Added video upload field
- `app/views/films/show.html.erb` - Added Video.js player
- `app/views/layouts/application.html.erb` - Added Video.js CDN links
- `Gemfile` - Added streamio-ffmpeg gem

### Video Player Features
- Responsive (adapts to screen size)
- Custom themed play button (matches Streetwatch colors)
- Keyboard shortcuts (Space to play/pause, arrows for seek, etc.)
- Fullscreen support
- Mobile-friendly touch controls

## Troubleshooting

### Thumbnail not generating
- Make sure FFmpeg is installed: `ffmpeg -version`
- Check Rails logs for errors: `tail -f log/development.log`
- Verify video file is valid and not corrupted

### Video not playing
- Check browser console for errors
- Verify video format is supported (MP4 with H.264 codec is most compatible)
- Ensure Active Storage is configured correctly

### Large file uploads timing out
- Increase upload timeout in `config/puma.rb`:
```ruby
worker_timeout 600  # 10 minutes
```
- Configure nginx/apache timeouts if using reverse proxy
- Consider direct-to-S3 uploads for very large files

## Future Enhancements (Optional)

1. **Video Transcoding** - Convert all videos to optimized web formats
2. **Multiple Quality Levels** - Generate 720p, 1080p versions
3. **Streaming** - Use services like Mux or Cloudflare Stream
4. **Progress Tracking** - Remember playback position
5. **Download Options** - Allow users to download videos
