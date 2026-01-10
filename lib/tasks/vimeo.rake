namespace :vimeo do
  desc "Update metadata for existing Vimeo videos that are missing runtime, company info, or release date"
  task update_metadata: :environment do
    puts "Finding Vimeo videos with missing metadata..."

    # Find all films with Vimeo URLs that are missing runtime, company info, or release date
    vimeo_films = Film.where("youtube_url LIKE ?", "%vimeo.com%")
                      .where("runtime IS NULL OR runtime = 0 OR (company IS NULL OR company = '') OR release_date IS NULL")

    puts "Found #{vimeo_films.count} Vimeo films with missing metadata"

    updated_count = 0
    failed_count = 0

    vimeo_films.find_each do |film|
      print "Processing film #{film.friendly_id} (#{film.title})... "

      begin
        if film.vimeo_video_id.present?
          require 'open-uri'
          require 'json'

          oembed_url = "https://vimeo.com/api/oembed.json?url=https://vimeo.com/#{film.vimeo_video_id}"
          oembed_response = URI.open(oembed_url).read
          oembed_data = JSON.parse(oembed_response)

          # Manually call the populate method
          film.send(:populate_vimeo_metadata, oembed_data)

          puts "✓ Updated"
          updated_count += 1
        else
          puts "✗ Could not extract Vimeo ID"
          failed_count += 1
        end
      rescue => e
        puts "✗ Failed: #{e.message}"
        failed_count += 1
      end

      # Be nice to Vimeo's API
      sleep 0.5
    end

    puts "\n" + "="*60
    puts "Metadata update complete!"
    puts "Successfully updated: #{updated_count}"
    puts "Failed: #{failed_count}"
    puts "="*60
  end

  desc "Re-download thumbnails for all Vimeo videos"
  task update_thumbnails: :environment do
    puts "Finding Vimeo videos..."

    vimeo_films = Film.where("youtube_url LIKE ?", "%vimeo.com%")

    puts "Found #{vimeo_films.count} Vimeo films"
    puts "Would you like to update ALL thumbnails or only missing ones? (all/missing)"
    print "> "

    choice = STDIN.gets.chomp.downcase

    if choice == "missing"
      vimeo_films = vimeo_films.left_joins(:thumbnail_attachment)
                               .where(active_storage_attachments: { id: nil })
      puts "Filtering to #{vimeo_films.count} films with missing thumbnails"
    end

    updated_count = 0
    failed_count = 0

    vimeo_films.find_each do |film|
      print "Processing film #{film.friendly_id} (#{film.title})... "

      begin
        if film.vimeo_video_id.present?
          # Purge existing thumbnail if updating all
          film.thumbnail.purge if choice == "all" && film.thumbnail.attached?

          # Call the download method
          film.send(:download_vimeo_thumbnail)

          puts "✓ Updated"
          updated_count += 1
        else
          puts "✗ Could not extract Vimeo ID"
          failed_count += 1
        end
      rescue => e
        puts "✗ Failed: #{e.message}"
        failed_count += 1
      end

      # Be nice to Vimeo's API
      sleep 0.5
    end

    puts "\n" + "="*60
    puts "Thumbnail update complete!"
    puts "Successfully updated: #{updated_count}"
    puts "Failed: #{failed_count}"
    puts "="*60
  end
end
