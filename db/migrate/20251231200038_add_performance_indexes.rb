# db/migrate/20251231200038_add_performance_indexes.rb
# Performance indexes for optimizing common queries

class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Composite indexes for common queries

    # Films indexes (based on actual columns)
    add_index :films, [:user_id, :created_at], name: 'index_films_on_user_and_created_at', if_not_exists: true
    add_index :films, [:film_type, :created_at], name: 'index_films_on_type_and_created_at', if_not_exists: true
    add_index :films, :film_type, name: 'index_films_on_film_type', if_not_exists: true
    add_index :films, :release_date, name: 'index_films_on_release_date', if_not_exists: true
    add_index :films, :filmer_user_id, name: 'index_films_on_filmer_user_id', if_not_exists: true
    add_index :films, :editor_user_id, name: 'index_films_on_editor_user_id', if_not_exists: true

    # Optimize film associations (if tables exist) - all use user_id
    if ActiveRecord::Base.connection.table_exists?(:film_riders)
      add_index :film_riders, [:film_id, :user_id], name: 'index_film_riders_on_film_and_user', if_not_exists: true
      add_index :film_riders, :user_id, name: 'index_film_riders_on_user_id', if_not_exists: true
    end

    if ActiveRecord::Base.connection.table_exists?(:film_filmers)
      add_index :film_filmers, [:film_id, :user_id], name: 'index_film_filmers_on_film_and_user', if_not_exists: true
      add_index :film_filmers, :user_id, name: 'index_film_filmers_on_user_id', if_not_exists: true
    end

    if ActiveRecord::Base.connection.table_exists?(:film_companies)
      add_index :film_companies, [:film_id, :user_id], name: 'index_film_companies_on_film_and_user', if_not_exists: true
      add_index :film_companies, :user_id, name: 'index_film_companies_on_user_id', if_not_exists: true
    end

    # Users indexes (based on actual columns)
    add_index :users, :created_at, name: 'index_users_on_created_at', if_not_exists: true
    add_index :users, :profile_type, name: 'index_users_on_profile_type', if_not_exists: true
    add_index :users, :username, name: 'index_users_on_username', if_not_exists: true

    # Photos indexes (based on actual columns)
    add_index :photos, [:user_id, :created_at], name: 'index_photos_on_user_and_created_at', if_not_exists: true
    add_index :photos, [:album_id, :created_at], name: 'index_photos_on_album_and_created_at', if_not_exists: true
    add_index :photos, :photographer_user_id, name: 'index_photos_on_photographer_user_id', if_not_exists: true

    # Comments indexes (if table exists)
    if ActiveRecord::Base.connection.table_exists?(:comments)
      add_index :comments, [:film_id, :created_at], name: 'index_comments_on_film_and_created_at', if_not_exists: true
      if ActiveRecord::Base.connection.column_exists?(:comments, :parent_id)
        add_index :comments, :parent_id, name: 'index_comments_on_parent_id', if_not_exists: true
      end
    end

    # Favorites indexes (if table exists)
    if ActiveRecord::Base.connection.table_exists?(:favorites)
      add_index :favorites, [:film_id, :created_at], name: 'index_favorites_on_film_and_created_at', if_not_exists: true
      add_index :favorites, [:user_id, :film_id], name: 'index_favorites_on_user_and_film', if_not_exists: true
    end

    # Follows indexes (if table exists)
    if ActiveRecord::Base.connection.table_exists?(:follows)
      add_index :follows, [:follower_id, :followed_id], name: 'index_follows_on_follower_and_followed', if_not_exists: true
      add_index :follows, :followed_id, name: 'index_follows_on_followed_id', if_not_exists: true
    end

    # Notifications indexes (if table exists)
    if ActiveRecord::Base.connection.table_exists?(:notifications)
      if ActiveRecord::Base.connection.column_exists?(:notifications, :recipient_id)
        add_index :notifications, [:recipient_id, :created_at], name: 'index_notifications_on_recipient_and_created', if_not_exists: true
      end
      if ActiveRecord::Base.connection.column_exists?(:notifications, :notifiable_type) &&
         ActiveRecord::Base.connection.column_exists?(:notifications, :notifiable_id)
        add_index :notifications, [:notifiable_type, :notifiable_id], name: 'index_notifications_on_notifiable', if_not_exists: true
      end
    end

    # Full text search indexes for PostgreSQL only
    if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'
      # Add GIN indexes for full text search
      execute <<-SQL
        CREATE INDEX IF NOT EXISTS index_films_on_title_gin ON films USING gin(to_tsvector('english', title));
        CREATE INDEX IF NOT EXISTS index_films_on_description_gin ON films USING gin(to_tsvector('english', COALESCE(description, '')));
        CREATE INDEX IF NOT EXISTS index_users_on_username_gin ON users USING gin(to_tsvector('english', username));
        CREATE INDEX IF NOT EXISTS index_users_on_bio_gin ON users USING gin(to_tsvector('english', COALESCE(bio, '')));
      SQL
    end
  end
end
