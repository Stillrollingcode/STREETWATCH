namespace :films do
  desc "Set skip_youtube_thumbnail=true for films without custom thumbnails (using YouTube auto-thumbnails)"
  task skip_auto_thumbnails: :environment do
    puts "Finding films without attached thumbnails that have YouTube URLs..."

    # Find films with YouTube URLs but no attached thumbnail
    films_to_update = Film.where.not(youtube_url: [nil, ''])
                          .left_joins(:thumbnail_attachment)
                          .where(active_storage_attachments: { id: nil })

    count = films_to_update.count
    puts "Found #{count} films to update"

    if count > 0
      films_to_update.update_all(skip_youtube_thumbnail: true)
      puts "Updated #{count} films to skip YouTube auto-thumbnails"
    else
      puts "No films need updating"
    end
  end

  desc "Preview films that would be affected by skip_auto_thumbnails task"
  task preview_auto_thumbnails: :environment do
    puts "Films without attached thumbnails that have YouTube URLs:"
    puts "-" * 60

    films = Film.where.not(youtube_url: [nil, ''])
                .left_joins(:thumbnail_attachment)
                .where(active_storage_attachments: { id: nil })
                .limit(50)

    films.each do |film|
      puts "#{film.friendly_id}: #{film.title} (#{film.youtube_url})"
    end

    total = Film.where.not(youtube_url: [nil, ''])
                .left_joins(:thumbnail_attachment)
                .where(active_storage_attachments: { id: nil })
                .count

    puts "-" * 60
    puts "Total: #{total} films would be updated"
  end
end
