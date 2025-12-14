class ProcessVideoJob < ApplicationJob
  queue_as :default

  # Retry with exponential backoff for transient failures
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(film_id)
    film = Film.find_by(id: film_id)
    return unless film&.video&.attached?

    Rails.logger.info "Processing video for film #{film_id}: #{film.title}"

    # Generate thumbnail if needed
    generate_thumbnail(film) unless film.thumbnail.attached?

    # Extract metadata
    extract_metadata(film)

    # Transcode to multiple qualities
    transcode_video(film)

    Rails.logger.info "Completed video processing for film #{film_id}"
  rescue => e
    Rails.logger.error "Video processing failed for film #{film_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  private

  def generate_thumbnail(film)
    Rails.logger.info "Generating thumbnail for film #{film.id}"

    film.video.open(tmpdir: Rails.root.join('tmp')) do |file|
      movie = FFMPEG::Movie.new(file.path)

      # Create a temporary file for the screenshot
      screenshot_path = Rails.root.join('tmp', "screenshot_#{film.id}_#{Time.current.to_i}.png")

      # Take screenshot at 1 second (or 10% into the video)
      time = [movie.duration * 0.1, 1].max

      # Calculate resolution
      width = movie.width || 1280
      height = movie.height || 720

      # Scale down if too large
      max_width = 1920
      if width > max_width
        scale_factor = max_width.to_f / width
        width = max_width
        height = (height * scale_factor).to_i
      end

      movie.screenshot(screenshot_path.to_s, seek_time: time, resolution: "#{width}x#{height}")

      # Attach the screenshot
      if File.exist?(screenshot_path)
        film.thumbnail.attach(
          io: File.open(screenshot_path),
          filename: "#{film.title.parameterize}_thumbnail.png",
          content_type: 'image/png'
        )

        File.delete(screenshot_path)
        Rails.logger.info "Thumbnail generated successfully for film #{film.id}"
      end
    end
  end

  def extract_metadata(film)
    Rails.logger.info "Extracting metadata for film #{film.id}"

    film.video.open(tmpdir: Rails.root.join('tmp')) do |file|
      movie = FFMPEG::Movie.new(file.path)

      # Extract runtime in minutes
      duration_in_minutes = (movie.duration / 60.0).round

      # Calculate aspect ratio
      if movie.width && movie.height && movie.width > 0 && movie.height > 0
        width = movie.width.to_f
        height = movie.height.to_f
        ratio = width / height

        calculated_ratio = case ratio
        when 0.5..0.6   then '9:16'
        when 0.7..0.8   then '4:5'
        when 1.2..1.4   then '4:3'
        when 1.7..1.8   then '16:9'
        when 2.3..2.4   then '21:9'
        else "#{width.to_i}:#{height.to_i}"
        end

        film.update_column(:aspect_ratio, calculated_ratio) if film.aspect_ratio != calculated_ratio
      end

      film.update_column(:runtime, duration_in_minutes) if film.runtime != duration_in_minutes
      Rails.logger.info "Metadata extracted for film #{film.id}"
    end
  end

  def transcode_video(film)
    Rails.logger.info "Transcoding video for film #{film.id}"

    film.video.open(tmpdir: Rails.root.join('tmp')) do |file|
      movie = FFMPEG::Movie.new(file.path)
      base_filename = film.title.parameterize

      # Define quality presets (ordered from highest to lowest)
      qualities = [
        { name: '4K', height: 2160, bitrate: '20000k', suffix: '4k' },
        { name: '2K', height: 1440, bitrate: '10000k', suffix: '2k' },
        { name: '1080p', height: 1080, bitrate: '5000k', suffix: '1080p' },
        { name: '720p', height: 720, bitrate: '2500k', suffix: '720p' },
        { name: '480p', height: 480, bitrate: '1000k', suffix: '480p' },
        { name: '360p', height: 360, bitrate: '500k', suffix: '360p' }
      ]

      qualities.each do |quality|
        # Skip if source video is smaller than target quality
        next if movie.height && movie.height < quality[:height]

        output_path = Rails.root.join('tmp', "#{base_filename}_#{quality[:suffix]}_#{Time.current.to_i}.mp4")

        # Calculate output dimensions maintaining aspect ratio
        if movie.width && movie.height
          aspect_ratio = movie.width.to_f / movie.height
          output_width = (quality[:height] * aspect_ratio).to_i
          # Ensure width is even (required for some codecs)
          output_width += 1 if output_width.odd?
        end

        # Transcode options
        options = {
          video_codec: 'libx264',
          audio_codec: 'aac',
          video_bitrate: quality[:bitrate],
          audio_bitrate: '128k',
          resolution: output_width ? "#{output_width}x#{quality[:height]}" : nil,
          custom: %w[-preset medium -crf 23 -movflags +faststart]
        }.compact

        begin
          movie.transcode(output_path.to_s, options)

          if File.exist?(output_path)
            # Attach transcoded video
            film.send("video_#{quality[:suffix]}").attach(
              io: File.open(output_path),
              filename: "#{base_filename}_#{quality[:suffix]}.mp4",
              content_type: 'video/mp4'
            )

            File.delete(output_path)
            Rails.logger.info "Created #{quality[:name]} version for film #{film.id}"
          end
        rescue => e
          Rails.logger.error "Failed to create #{quality[:name]} for film #{film.id}: #{e.message}"
        end
      end
    end
  end
end
