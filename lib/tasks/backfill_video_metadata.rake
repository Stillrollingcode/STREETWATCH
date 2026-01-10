namespace :data do
  desc "One-time task: Backfill metadata (runtime, company, release_date) for all existing YouTube and Vimeo videos"
  task backfill_video_metadata: :environment do
    puts "="*80
    puts "BACKFILLING VIDEO METADATA FOR EXISTING FILMS"
    puts "="*80
    puts ""
    puts "This task will:"
    puts "  1. Find all films with YouTube or Vimeo URLs"
    puts "  2. Fetch metadata (runtime, company, release_date) from video platforms"
    puts "  3. Update films that are missing this data"
    puts ""

    # Find all films with video URLs (YouTube or Vimeo)
    youtube_films = Film.where("youtube_url LIKE ? OR youtube_url LIKE ?", "%youtube.com%", "%youtu.be%")
    vimeo_films = Film.where("youtube_url LIKE ?", "%vimeo.com%")

    total_youtube = youtube_films.count
    total_vimeo = vimeo_films.count

    puts "Found #{total_youtube} YouTube films and #{total_vimeo} Vimeo films"
    puts ""

    # Statistics
    youtube_updated = 0
    youtube_failed = 0
    youtube_skipped = 0
    vimeo_updated = 0
    vimeo_failed = 0
    vimeo_skipped = 0

    # Process YouTube videos
    if total_youtube > 0
      puts "-" * 80
      puts "PROCESSING YOUTUBE VIDEOS"
      puts "-" * 80

      youtube_films.find_each.with_index do |film, index|
        print "[#{index + 1}/#{total_youtube}] #{film.friendly_id} - #{film.title.truncate(40)}... "

        # Check if we need to update anything
        needs_update = film.release_date.blank?

        if !needs_update
          puts "✓ Already has metadata"
          youtube_skipped += 1
          next
        end

        begin
          if film.youtube_video_id.present?
            # Call the metadata population method
            film.send(:populate_youtube_metadata)

            puts "✓ Updated"
            youtube_updated += 1
          else
            puts "✗ Could not extract YouTube ID"
            youtube_failed += 1
          end
        rescue => e
          puts "✗ Failed: #{e.message}"
          youtube_failed += 1
        end

        # Be nice to YouTube's servers
        sleep 1
      end
    end

    # Process Vimeo videos
    if total_vimeo > 0
      puts ""
      puts "-" * 80
      puts "PROCESSING VIMEO VIDEOS"
      puts "-" * 80

      vimeo_films.find_each.with_index do |film, index|
        print "[#{index + 1}/#{total_vimeo}] #{film.friendly_id} - #{film.title.truncate(40)}... "

        # Check if we need to update anything
        needs_update = film.runtime.blank? || film.release_date.blank? ||
                      (film.company.blank? && film.companies.empty?)

        if !needs_update
          puts "✓ Already has metadata"
          vimeo_skipped += 1
          next
        end

        begin
          if film.vimeo_video_id.present?
            require 'open-uri'
            require 'json'

            # Fetch oEmbed data
            oembed_url = "https://vimeo.com/api/oembed.json?url=https://vimeo.com/#{film.vimeo_video_id}"
            oembed_response = URI.open(oembed_url).read
            oembed_data = JSON.parse(oembed_response)

            # Call the metadata population method
            film.send(:populate_vimeo_metadata, oembed_data)

            puts "✓ Updated"
            vimeo_updated += 1
          else
            puts "✗ Could not extract Vimeo ID"
            vimeo_failed += 1
          end
        rescue => e
          puts "✗ Failed: #{e.message}"
          vimeo_failed += 1
        end

        # Be nice to Vimeo's servers
        sleep 0.5
      end
    end

    # Print summary
    puts ""
    puts "="*80
    puts "BACKFILL COMPLETE"
    puts "="*80
    puts ""
    puts "YouTube Videos:"
    puts "  Total:   #{total_youtube}"
    puts "  Updated: #{youtube_updated}"
    puts "  Skipped: #{youtube_skipped} (already had metadata)"
    puts "  Failed:  #{youtube_failed}"
    puts ""
    puts "Vimeo Videos:"
    puts "  Total:   #{total_vimeo}"
    puts "  Updated: #{vimeo_updated}"
    puts "  Skipped: #{vimeo_skipped} (already had metadata)"
    puts "  Failed:  #{vimeo_failed}"
    puts ""
    puts "Total films updated: #{youtube_updated + vimeo_updated}"
    puts "="*80
  end
end
