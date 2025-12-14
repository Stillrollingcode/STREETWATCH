namespace :films do
  desc "Regenerate thumbnails for all films"
  task regenerate_thumbnails: :environment do
    Film.where.not(video_attachment_id: nil).find_each do |film|
      if film.thumbnail.attached?
        puts "Purging thumbnail for: #{film.title}"
        film.thumbnail.purge
      end

      puts "Regenerating thumbnail for: #{film.title}"
      film.send(:generate_thumbnail_from_video)
      puts "Done: #{film.title}\n"
    end

    puts "All thumbnails regenerated!"
  end

  desc "Regenerate thumbnail for a specific film by ID"
  task :regenerate_thumbnail, [:film_id] => :environment do |t, args|
    film = Film.find(args[:film_id])

    if film.thumbnail.attached?
      puts "Purging existing thumbnail..."
      film.thumbnail.purge
    end

    puts "Regenerating thumbnail..."
    film.send(:generate_thumbnail_from_video)
    puts "Done!"
  end
end
