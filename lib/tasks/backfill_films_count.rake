namespace :users do
  desc "Backfill films_count for all users"
  task backfill_films_count: :environment do
    puts "Backfilling films_count for all users..."

    total = User.count
    updated = 0

    User.find_each.with_index do |user, index|
      user.update_films_count!
      updated += 1

      if (index + 1) % 100 == 0
        puts "  Processed #{index + 1}/#{total} users..."
      end
    end

    puts "Done! Updated films_count for #{updated} users."
  end

  desc "Reset and recalculate films_count for a specific user by ID or username"
  task :reset_films_count, [:identifier] => :environment do |t, args|
    identifier = args[:identifier]

    if identifier.blank?
      puts "Usage: rake users:reset_films_count[user_id_or_username]"
      exit 1
    end

    user = User.find_by(id: identifier) || User.find_by(username: identifier)

    if user.nil?
      puts "User not found: #{identifier}"
      exit 1
    end

    old_count = user.films_count
    user.update_films_count!
    new_count = user.reload.films_count

    puts "Updated #{user.username}: #{old_count} -> #{new_count} films"
  end
end
