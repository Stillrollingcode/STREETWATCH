namespace :data do
  desc "Backfill friendly_ids for existing records"
  task backfill_friendly_ids: :environment do
    puts "Backfilling friendly_ids for Films..."
    Film.where(friendly_id: nil).find_each do |film|
      film.send(:generate_friendly_id)
      if film.save(validate: false)
        puts "  Film ##{film.id}: #{film.friendly_id}"
      else
        puts "  ERROR: Film ##{film.id} failed to save"
      end
    end

    puts "\nBackfilling friendly_ids for Photos..."
    Photo.where(friendly_id: nil).find_each do |photo|
      photo.send(:generate_friendly_id)
      if photo.save(validate: false)
        puts "  Photo ##{photo.id}: #{photo.friendly_id}"
      else
        puts "  ERROR: Photo ##{photo.id} failed to save"
      end
    end

    puts "\nBackfilling friendly_ids for Albums..."
    Album.where(friendly_id: nil).find_each do |album|
      album.send(:generate_friendly_id)
      if album.save(validate: false)
        puts "  Album ##{album.id}: #{album.friendly_id}"
      else
        puts "  ERROR: Album ##{album.id} failed to save"
      end
    end

    puts "\n✓ Done!"
  end
end
