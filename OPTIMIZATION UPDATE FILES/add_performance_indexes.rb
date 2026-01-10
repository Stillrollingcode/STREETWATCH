# db/migrate/add_performance_indexes.rb
# Run with: rails generate migration AddPerformanceIndexes
# Then copy this content and run: rails db:migrate

class AddPerformanceIndexes < ActiveRecord::Migration[7.1]
  def change
    # Composite indexes for common queries
    
    # Films indexes
    add_index :films, [:published, :created_at], name: 'index_films_on_published_and_created_at'
    add_index :films, [:user_id, :published, :created_at], name: 'index_films_on_user_published_created'
    add_index :films, [:year, :published], name: 'index_films_on_year_and_published'
    add_index :films, :film_type, name: 'index_films_on_film_type'
    
    # Optimize film associations
    add_index :film_riders, [:film_id, :rider_id], unique: true, name: 'index_film_riders_unique'
    add_index :film_riders, :rider_id, name: 'index_film_riders_on_rider_id'
    
    add_index :film_filmers, [:film_id, :filmer_id], unique: true, name: 'index_film_filmers_unique'
    add_index :film_filmers, :filmer_id, name: 'index_film_filmers_on_filmer_id'
    
    add_index :film_companies, [:film_id, :company_id], unique: true, name: 'index_film_companies_unique'
    add_index :film_companies, :company_id, name: 'index_film_companies_on_company_id'
    
    # Users indexes
    add_index :users, [:active, :created_at], name: 'index_users_on_active_and_created_at'
    add_index :users, [:active, :last_sign_in_at], name: 'index_users_on_active_and_last_sign_in'
    add_index :users, :profile_type, name: 'index_users_on_profile_type'
    add_index :users, :username, unique: true, name: 'index_users_on_username_unique'
    
    # Photos indexes
    add_index :photos, [:user_id, :published, :created_at], name: 'index_photos_on_user_published_created'
    add_index :photos, [:album_id, :published], name: 'index_photos_on_album_and_published'
    
    # Comments indexes for faster counting
    add_index :comments, [:film_id, :created_at], name: 'index_comments_on_film_and_created'
    add_index :comments, :parent_id, name: 'index_comments_on_parent_id'
    
    # Favorites indexes
    add_index :favorites, [:film_id, :created_at], name: 'index_favorites_on_film_and_created'
    add_index :favorites, [:user_id, :film_id], unique: true, name: 'index_favorites_unique'
    
    # Follows indexes
    add_index :follows, [:follower_id, :followed_id], unique: true, name: 'index_follows_unique'
    add_index :follows, :followed_id, name: 'index_follows_on_followed_id'
    
    # Notifications indexes
    add_index :notifications, [:recipient_id, :read_at, :created_at], name: 'index_notifications_on_recipient_read_created'
    add_index :notifications, [:notifiable_type, :notifiable_id], name: 'index_notifications_on_notifiable'
    
    # Full text search indexes for PostgreSQL
    if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'
      # Add GIN indexes for full text search
      execute <<-SQL
        CREATE INDEX index_films_on_title_gin ON films USING gin(to_tsvector('english', title));
        CREATE INDEX index_films_on_description_gin ON films USING gin(to_tsvector('english', description));
        CREATE INDEX index_users_on_username_gin ON users USING gin(to_tsvector('english', username));
        CREATE INDEX index_users_on_bio_gin ON users USING gin(to_tsvector('english', bio));
      SQL
    end
  end
  
  def down
    # Remove all custom indexes
    remove_index :films, name: 'index_films_on_published_and_created_at'
    remove_index :films, name: 'index_films_on_user_published_created'
    remove_index :films, name: 'index_films_on_year_and_published'
    remove_index :films, name: 'index_films_on_film_type'
    
    remove_index :film_riders, name: 'index_film_riders_unique'
    remove_index :film_riders, name: 'index_film_riders_on_rider_id'
    
    remove_index :film_filmers, name: 'index_film_filmers_unique'
    remove_index :film_filmers, name: 'index_film_filmers_on_filmer_id'
    
    remove_index :film_companies, name: 'index_film_companies_unique'
    remove_index :film_companies, name: 'index_film_companies_on_company_id'
    
    remove_index :users, name: 'index_users_on_active_and_created_at'
    remove_index :users, name: 'index_users_on_active_and_last_sign_in'
    remove_index :users, name: 'index_users_on_profile_type'
    remove_index :users, name: 'index_users_on_username_unique'
    
    remove_index :photos, name: 'index_photos_on_user_published_created'
    remove_index :photos, name: 'index_photos_on_album_and_published'
    
    remove_index :comments, name: 'index_comments_on_film_and_created'
    remove_index :comments, name: 'index_comments_on_parent_id'
    
    remove_index :favorites, name: 'index_favorites_on_film_and_created'
    remove_index :favorites, name: 'index_favorites_unique'
    
    remove_index :follows, name: 'index_follows_unique'
    remove_index :follows, name: 'index_follows_on_followed_id'
    
    remove_index :notifications, name: 'index_notifications_on_recipient_read_created'
    remove_index :notifications, name: 'index_notifications_on_notifiable'
    
    if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'
      execute <<-SQL
        DROP INDEX IF EXISTS index_films_on_title_gin;
        DROP INDEX IF EXISTS index_films_on_description_gin;
        DROP INDEX IF EXISTS index_users_on_username_gin;
        DROP INDEX IF EXISTS index_users_on_bio_gin;
      SQL
    end
  end
end
