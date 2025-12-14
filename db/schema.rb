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

ActiveRecord::Schema[8.0].define(version: 2025_12_13_160120) do
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

  create_table "comments", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "film_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "parent_id"
    t.index ["film_id", "created_at"], name: "index_comments_on_film_id_and_created_at"
    t.index ["film_id"], name: "index_comments_on_film_id"
    t.index ["parent_id"], name: "index_comments_on_parent_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "favorites", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "film_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["film_id"], name: "index_favorites_on_film_id"
    t.index ["user_id", "film_id"], name: "index_favorites_on_user_id_and_film_id", unique: true
    t.index ["user_id"], name: "index_favorites_on_user_id"
  end

  create_table "film_riders", force: :cascade do |t|
    t.integer "film_id", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["editor_user_id"], name: "index_films_on_editor_user_id"
    t.index ["film_type"], name: "index_films_on_film_type"
    t.index ["filmer_user_id"], name: "index_films_on_filmer_user_id"
    t.index ["release_date"], name: "index_films_on_release_date"
    t.index ["title"], name: "index_films_on_title"
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
    t.index ["user_id", "name"], name: "index_playlists_on_user_id_and_name"
    t.index ["user_id"], name: "index_playlists_on_user_id"
  end

  create_table "user_preferences", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "theme", default: "dark"
    t.integer "accent_hue", default: 145
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
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
    t.string "rider_type"
    t.boolean "subscription_active"
    t.string "username", default: "", null: false
    t.text "bio"
    t.text "sponsor_requests"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "comments", "comments", column: "parent_id"
  add_foreign_key "comments", "films"
  add_foreign_key "comments", "users"
  add_foreign_key "favorites", "films"
  add_foreign_key "favorites", "users"
  add_foreign_key "film_riders", "films"
  add_foreign_key "film_riders", "users"
  add_foreign_key "films", "users", column: "editor_user_id"
  add_foreign_key "films", "users", column: "filmer_user_id"
  add_foreign_key "playlist_films", "films"
  add_foreign_key "playlist_films", "playlists"
  add_foreign_key "playlists", "users"
  add_foreign_key "user_preferences", "users"
end
