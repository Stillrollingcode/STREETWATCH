# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_01_28_000002) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "role", default: "moderator", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_admin_users_on_role"
  end

  create_table "albums", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.date "date"
    t.integer "user_id", null: false
    t.string "friendly_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_public", default: true, null: false
    t.index ["date"], name: "index_albums_on_date"
    t.index ["friendly_id"], name: "index_albums_on_friendly_id", unique: true
    t.index ["user_id"], name: "index_albums_on_user_id"
  end

  create_table "comment_likes", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "likeable_type", null: false
    t.integer "likeable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["likeable_type", "likeable_id"], name: "index_comment_likes_on_likeable"
    t.index ["user_id", "likeable_type", "likeable_id"], name: "index_comment_likes_uniqueness", unique: true
    t.index ["user_id"], name: "index_comment_likes_on_user_id"
  end

  create_table "comments", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "film_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "parent_id"
    t.string "friendly_id"
    t.index ["film_id", "created_at"], name: "index_comments_on_film_and_created_at"
    t.index ["film_id", "created_at"], name: "index_comments_on_film_id_and_created_at"
    t.index ["film_id"], name: "index_comments_on_film_id"
    t.index ["friendly_id"], name: "index_comments_on_friendly_id", unique: true
    t.index ["parent_id"], name: "index_comments_on_parent_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "data_imports", force: :cascade do |t|
    t.string "import_type"
    t.string "status", default: "pending"
    t.integer "total_rows", default: 0
    t.integer "successful_rows", default: 0
    t.integer "failed_rows", default: 0
    t.text "error_log"
    t.json "column_mapping"
    t.integer "admin_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_user_id"], name: "index_data_imports_on_admin_user_id"
    t.index ["import_type"], name: "index_data_imports_on_import_type"
    t.index ["status"], name: "index_data_imports_on_status"
  end

  create_table "favorites", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "film_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["film_id", "created_at"], name: "index_favorites_on_film_and_created"
    t.index ["film_id", "created_at"], name: "index_favorites_on_film_and_created_at"
    t.index ["film_id"], name: "index_favorites_on_film_id"
    t.index ["user_id", "film_id"], name: "index_favorites_on_user_and_film"
    t.index ["user_id", "film_id"], name: "index_favorites_on_user_id_and_film_id", unique: true
    t.index ["user_id"], name: "index_favorites_on_user_id"
  end

  create_table "film_approvals", force: :cascade do |t|
    t.integer "film_id", null: false
    t.integer "approver_id", null: false
    t.string "approval_type", null: false
    t.string "status", default: "pending", null: false
    t.text "rejection_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "friendly_id"
    t.index ["approver_id"], name: "index_film_approvals_on_approver_id"
    t.index ["film_id", "approver_id", "approval_type"], name: "index_film_approvals_unique", unique: true
    t.index ["film_id", "status"], name: "index_film_approvals_on_film_id_and_status"
    t.index ["film_id"], name: "index_film_approvals_on_film_id"
    t.index ["friendly_id"], name: "index_film_approvals_on_friendly_id", unique: true
    t.index ["status"], name: "index_film_approvals_on_status"
  end

  create_table "film_companies", force: :cascade do |t|
    t.integer "film_id", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["film_id", "user_id"], name: "index_film_companies_on_film_and_user"
    t.index ["film_id", "user_id"], name: "index_film_companies_on_film_id_and_user_id", unique: true
    t.index ["film_id"], name: "index_film_companies_on_film_id"
    t.index ["user_id"], name: "index_film_companies_on_user_id"
  end

  create_table "film_filmers", force: :cascade do |t|
    t.integer "film_id", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["film_id", "user_id"], name: "index_film_filmers_on_film_and_user"
    t.index ["film_id", "user_id"], name: "index_film_filmers_on_film_id_and_user_id", unique: true
    t.index ["film_id"], name: "index_film_filmers_on_film_id"
    t.index ["user_id"], name: "index_film_filmers_on_user_id"
  end

  create_table "film_reviews", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "film_id", null: false
    t.integer "rating", null: false
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["film_id"], name: "index_film_reviews_on_film_id"
    t.index ["user_id", "film_id"], name: "index_film_reviews_on_user_id_and_film_id", unique: true
    t.index ["user_id"], name: "index_film_reviews_on_user_id"
  end

  create_table "film_riders", force: :cascade do |t|
    t.integer "film_id", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["film_id", "user_id"], name: "index_film_riders_on_film_and_user"
    t.index ["film_id", "user_id"], name: "index_film_riders_on_film_id_and_user_id", unique: true
    t.index ["film_id"], name: "index_film_riders_on_film_id"
    t.index ["user_id"], name: "index_film_riders_on_user_id"
  end

  create_table "films", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.date "release_date"
    t.string "custom_filmer_name"
    t.string "custom_editor_name"
    t.string "company"
    t.integer "runtime"
    t.text "music_featured"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "film_type", default: "full_length"
    t.string "parent_film_title"
    t.integer "filmer_user_id"
    t.integer "editor_user_id"
    t.text "custom_riders"
    t.string "aspect_ratio", default: "16:9"
    t.string "youtube_url"
    t.integer "company_user_id"
    t.integer "user_id"
    t.string "friendly_id"
    t.integer "views_count", default: 0, null: false
    t.integer "reviews_count", default: 0, null: false
    t.decimal "average_rating_cache", precision: 3, scale: 1, default: "0.0", null: false
    t.boolean "skip_youtube_thumbnail", default: false
    t.index ["average_rating_cache"], name: "index_films_on_average_rating_cache"
    t.index ["company_user_id"], name: "index_films_on_company_user_id"
    t.index ["created_at"], name: "index_films_on_created_at"
    t.index ["editor_user_id"], name: "index_films_on_editor_user_id"
    t.index ["film_type", "created_at"], name: "index_films_on_type_and_created_at"
    t.index ["film_type"], name: "index_films_on_film_type"
    t.index ["filmer_user_id"], name: "index_films_on_filmer_user_id"
    t.index ["friendly_id"], name: "index_films_on_friendly_id", unique: true
    t.index ["release_date"], name: "index_films_on_release_date"
    t.index ["title"], name: "index_films_on_title"
    t.index ["user_id", "created_at"], name: "index_films_on_user_and_created"
    t.index ["user_id", "created_at"], name: "index_films_on_user_and_created_at"
    t.index ["user_id"], name: "index_films_on_user_id"
  end

  create_table "follows", force: :cascade do |t|
    t.integer "follower_id", null: false
    t.integer "followed_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["followed_id"], name: "index_follows_on_followed_id"
    t.index ["follower_id", "followed_id"], name: "index_follows_on_follower_and_followed"
    t.index ["follower_id", "followed_id"], name: "index_follows_on_follower_id_and_followed_id", unique: true
  end

  create_table "hidden_profile_films", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "film_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["film_id"], name: "index_hidden_profile_films_on_film_id"
    t.index ["user_id", "film_id"], name: "index_hidden_profile_films_on_user_id_and_film_id", unique: true
    t.index ["user_id"], name: "index_hidden_profile_films_on_user_id"
  end

  create_table "hidden_profile_photos", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "photo_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["photo_id"], name: "index_hidden_profile_photos_on_photo_id"
    t.index ["user_id", "photo_id"], name: "index_hidden_profile_photos_on_user_id_and_photo_id", unique: true
    t.index ["user_id"], name: "index_hidden_profile_photos_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "actor_id", null: false
    t.string "notifiable_type", null: false
    t.integer "notifiable_id", null: false
    t.string "action", null: false
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable_type_and_notifiable_id"
    t.index ["user_id", "read_at", "created_at"], name: "index_notifications_on_user_id_and_read_at_and_created_at"
  end

  create_table "photo_approvals", force: :cascade do |t|
    t.integer "photo_id", null: false
    t.integer "approver_id", null: false
    t.string "approval_type", null: false
    t.string "status", default: "pending", null: false
    t.text "rejection_reason"
    t.string "friendly_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approver_id"], name: "index_photo_approvals_on_approver_id"
    t.index ["friendly_id"], name: "index_photo_approvals_on_friendly_id", unique: true
    t.index ["photo_id", "approver_id", "approval_type"], name: "index_photo_approvals_unique", unique: true
    t.index ["photo_id"], name: "index_photo_approvals_on_photo_id"
  end

  create_table "photo_comments", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "photo_id", null: false
    t.text "body", null: false
    t.integer "parent_id"
    t.string "friendly_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["friendly_id"], name: "index_photo_comments_on_friendly_id", unique: true
    t.index ["parent_id"], name: "index_photo_comments_on_parent_id"
    t.index ["photo_id", "created_at"], name: "index_photo_comments_on_photo_id_and_created_at"
    t.index ["photo_id"], name: "index_photo_comments_on_photo_id"
    t.index ["user_id"], name: "index_photo_comments_on_user_id"
  end

  create_table "photo_riders", force: :cascade do |t|
    t.integer "photo_id", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["photo_id", "user_id"], name: "index_photo_riders_on_photo_id_and_user_id", unique: true
    t.index ["photo_id"], name: "index_photo_riders_on_photo_id"
    t.index ["user_id"], name: "index_photo_riders_on_user_id"
  end

  create_table "photos", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.date "date_taken"
    t.integer "album_id", null: false
    t.integer "user_id", null: false
    t.integer "photographer_user_id"
    t.integer "company_user_id"
    t.string "custom_photographer_name"
    t.text "custom_riders"
    t.string "friendly_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["album_id", "created_at"], name: "index_photos_on_album_and_created_at"
    t.index ["album_id"], name: "index_photos_on_album_id"
    t.index ["company_user_id"], name: "index_photos_on_company_user_id"
    t.index ["date_taken"], name: "index_photos_on_date_taken"
    t.index ["friendly_id"], name: "index_photos_on_friendly_id", unique: true
    t.index ["photographer_user_id"], name: "index_photos_on_photographer_user_id"
    t.index ["user_id", "created_at"], name: "index_photos_on_user_and_created"
    t.index ["user_id", "created_at"], name: "index_photos_on_user_and_created_at"
    t.index ["user_id"], name: "index_photos_on_user_id"
  end

  create_table "playlist_films", force: :cascade do |t|
    t.integer "playlist_id", null: false
    t.integer "film_id", null: false
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["film_id"], name: "index_playlist_films_on_film_id"
    t.index ["playlist_id", "film_id"], name: "index_playlist_films_on_playlist_id_and_film_id", unique: true
    t.index ["playlist_id", "position"], name: "index_playlist_films_on_playlist_id_and_position"
    t.index ["playlist_id"], name: "index_playlist_films_on_playlist_id"
  end

  create_table "playlists", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "friendly_id"
    t.boolean "is_public", default: true, null: false
    t.index ["friendly_id"], name: "index_playlists_on_friendly_id", unique: true
    t.index ["user_id", "name"], name: "index_playlists_on_user_id_and_name"
    t.index ["user_id"], name: "index_playlists_on_user_id"
  end

  create_table "profile_notification_settings", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "target_user_id", null: false
    t.boolean "notify_on_films", default: false
    t.boolean "notify_on_photos", default: false
    t.boolean "notify_on_articles", default: false
    t.boolean "muted", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "notify_on_featured_in_films", default: false
    t.boolean "notify_on_featured_in_photos", default: false
    t.boolean "notify_on_featured_in_articles", default: false
    t.index ["target_user_id"], name: "index_profile_notification_settings_on_target_user_id"
    t.index ["user_id", "target_user_id"], name: "index_profile_notifications_on_user_and_target", unique: true
  end

  create_table "sponsor_approvals", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "sponsor_id", null: false
    t.string "status", default: "pending", null: false
    t.text "rejection_reason"
    t.string "friendly_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["friendly_id"], name: "index_sponsor_approvals_on_friendly_id", unique: true
    t.index ["sponsor_id"], name: "index_sponsor_approvals_on_sponsor_id"
    t.index ["user_id", "sponsor_id"], name: "index_sponsor_approvals_on_user_id_and_sponsor_id", unique: true
    t.index ["user_id"], name: "index_sponsor_approvals_on_user_id"
  end

  create_table "tag_requests", force: :cascade do |t|
    t.integer "film_id", null: false
    t.integer "requester_id", null: false
    t.string "role", null: false
    t.string "status", default: "pending", null: false
    t.text "message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["film_id", "requester_id", "role"], name: "index_tag_requests_unique", unique: true
    t.index ["film_id"], name: "index_tag_requests_on_film_id"
    t.index ["requester_id"], name: "index_tag_requests_on_requester_id"
  end

  create_table "user_preferences", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "theme", default: "dark"
    t.integer "accent_hue", default: 145
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "email_notifications_enabled", default: true
    t.boolean "notify_on_new_follower", default: true
    t.boolean "notify_on_comment", default: true
    t.boolean "notify_on_mention", default: true
    t.boolean "notify_on_favorite", default: true
    t.string "content_tab_order", default: "films,photos,articles"
    t.boolean "notify_on_reply", default: true
    t.index ["user_id"], name: "index_user_preferences_on_user_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "profile_type"
    t.boolean "subscription_active"
    t.string "username", default: "", null: false
    t.text "bio"
    t.text "sponsor_requests"
    t.boolean "admin_created", default: false
    t.string "claim_token"
    t.datetime "claimed_at"
    t.boolean "email_visible", default: false
    t.string "friendly_id"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "films_count", default: 0, null: false
    t.integer "followers_count", default: 0, null: false
    t.integer "following_count", default: 0, null: false
    t.index "LOWER(username)", name: "index_users_on_lower_username"
    t.index ["claim_token"], name: "index_users_on_claim_token", unique: true
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["created_at"], name: "index_users_on_created_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["friendly_id"], name: "index_users_on_friendly_id", unique: true
    t.index ["profile_type"], name: "index_users_on_profile_type"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "albums", "users"
  add_foreign_key "comment_likes", "users"
  add_foreign_key "comments", "comments", column: "parent_id"
  add_foreign_key "comments", "films"
  add_foreign_key "comments", "users"
  add_foreign_key "data_imports", "admin_users"
  add_foreign_key "favorites", "films"
  add_foreign_key "favorites", "users"
  add_foreign_key "film_approvals", "films"
  add_foreign_key "film_approvals", "users", column: "approver_id"
  add_foreign_key "film_companies", "films"
  add_foreign_key "film_companies", "users"
  add_foreign_key "film_filmers", "films"
  add_foreign_key "film_filmers", "users"
  add_foreign_key "film_reviews", "films"
  add_foreign_key "film_reviews", "users"
  add_foreign_key "film_riders", "films"
  add_foreign_key "film_riders", "users"
  add_foreign_key "films", "users"
  add_foreign_key "films", "users", column: "editor_user_id"
  add_foreign_key "films", "users", column: "filmer_user_id"
  add_foreign_key "follows", "users", column: "followed_id"
  add_foreign_key "follows", "users", column: "follower_id"
  add_foreign_key "hidden_profile_films", "films"
  add_foreign_key "hidden_profile_films", "users"
  add_foreign_key "hidden_profile_photos", "photos"
  add_foreign_key "hidden_profile_photos", "users"
  add_foreign_key "notifications", "users"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "photo_approvals", "photos"
  add_foreign_key "photo_approvals", "users", column: "approver_id"
  add_foreign_key "photo_comments", "photo_comments", column: "parent_id"
  add_foreign_key "photo_comments", "photos"
  add_foreign_key "photo_comments", "users"
  add_foreign_key "photo_riders", "photos"
  add_foreign_key "photo_riders", "users"
  add_foreign_key "photos", "albums"
  add_foreign_key "photos", "users"
  add_foreign_key "photos", "users", column: "company_user_id"
  add_foreign_key "photos", "users", column: "photographer_user_id"
  add_foreign_key "playlist_films", "films"
  add_foreign_key "playlist_films", "playlists"
  add_foreign_key "playlists", "users"
  add_foreign_key "profile_notification_settings", "users"
  add_foreign_key "profile_notification_settings", "users", column: "target_user_id"
  add_foreign_key "sponsor_approvals", "users"
  add_foreign_key "sponsor_approvals", "users", column: "sponsor_id"
  add_foreign_key "tag_requests", "films"
  add_foreign_key "tag_requests", "users", column: "requester_id"
  add_foreign_key "user_preferences", "users"
end
