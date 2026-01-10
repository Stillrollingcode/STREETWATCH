namespace :youtube do
  desc "Update metadata for existing YouTube videos that are missing release date"
  task update_metadata: :environment do
    puts "Finding YouTube videos with missing metadata..."

    # Find all films with YouTube URLs that are missing release date
    youtube_films = Film.where("youtube_url LIKE ? OR youtube_url LIKE ?", "%youtube.com%", "%youtu.be%")
                        .where("release_date IS NULL")

    puts "Found #{youtube_films.count} YouTube films with missing release date"

    updated_count = 0
    failed_count = 0

    youtube_films.find_each do |film|
      print "Processing film #{film.friendly_id} (#{film.title})... "

      begin
        if film.youtube_video_id.present?
          # Manually call the populate method
          film.send(:populate_youtube_metadata)

          puts "✓ Updated"
          updated_count += 1
        else
          puts "✗ Could not extract YouTube ID"
          failed_count += 1
        end
      rescue => e
        puts "✗ Failed: #{e.message}"
        failed_count += 1
      end

      # Be nice to YouTube
      sleep 1
    end

    puts "\n" + "="*60
    puts "Metadata update complete!"
    puts "Successfully updated: #{updated_count}"
    puts "Failed: #{failed_count}"
    puts "="*60
  end

  desc "Re-download thumbnails for all YouTube videos"
  task update_thumbnails: :environment do
    puts "Finding YouTube videos..."

    youtube_films = Film.where("youtube_url LIKE ? OR youtube_url LIKE ?", "%youtube.com%", "%youtu.be%")

    puts "Found #{youtube_films.count} YouTube films"
    puts "Would you like to update ALL thumbnails or only missing ones? (all/missing)"
    print "> "

    choice = STDIN.gets.chomp.downcase

    if choice == "missing"
      youtube_films = youtube_films.left_joins(:thumbnail_attachment)
                                   .where(active_storage_attachments: { id: nil })
      puts "Filtering to #{youtube_films.count} films with missing thumbnails"
    end

    updated_count = 0
    failed_count = 0

    youtube_films.find_each do |film|
      print "Processing film #{film.friendly_id} (#{film.title})... "

      begin
        if film.youtube_video_id.present?
          # Purge existing thumbnail if updating all
          film.thumbnail.purge if choice == "all" && film.thumbnail.attached?

          # Call the download method
          film.send(:download_youtube_thumbnail)

          puts "✓ Updated"
          updated_count += 1
        else
          puts "✗ Could not extract YouTube ID"
          failed_count += 1
        end
      rescue => e
        puts "✗ Failed: #{e.message}"
        failed_count += 1
      end

      # Be nice to YouTube
      sleep 1
    end

    puts "\n" + "="*60
    puts "Thumbnail update complete!"
    puts "Successfully updated: #{updated_count}"
    puts "Failed: #{failed_count}"
    puts "="*60
  end
end
