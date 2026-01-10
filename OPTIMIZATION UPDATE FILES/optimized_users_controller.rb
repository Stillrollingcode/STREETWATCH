# app/controllers/users_controller.rb
# Optimized version with eager loading and query optimization

class UsersController < ApplicationController
  before_action :set_user, only: [:show, :following, :followers]
  before_action :set_cache_headers, only: [:index, :show]
  
  def index
    @initial_load_count = 24
    
    # Base query with eager loading
    users_base = User.active
      .includes(:user_preference, avatar_attachment: :blob)
      .joins("LEFT JOIN films ON films.user_id = users.id")
      .joins("LEFT JOIN photos ON photos.user_id = users.id")
      .select("users.*, COUNT(DISTINCT films.id) as films_count, COUNT(DISTINCT photos.id) as photos_count")
      .group("users.id")
    
    # Apply filters
    if params[:filter].present?
      users_base = apply_user_filters(users_base)
    end
    
    # Apply search
    if params[:query].present?
      users_base = users_base.search_by_fields(
        params[:query],
        :username, :name, :bio
      )
    end
    
    # Sort options with database indexes
    users_base = apply_sort_order(users_base)
    
    # Initial load vs pagination
    if request.format.html? && !params[:page]
      @users = users_base.limit(@initial_load_count)
      @total_count = User.active.count # Cached count
      @has_more = @total_count > @initial_load_count
      
      # Preload follower counts
      preload_user_stats(@users)
    else
      @users = users_base.page(params[:page]).per(24)
      preload_user_stats(@users)
    end
    
    respond_to do |format|
      format.html do
        if params[:page]
          render partial: 'users/user_cards', locals: { users: @users }
        else
          render :index
        end
      end
      format.json { render json: users_json_response(@users) }
    end
  end
  
  def show
    # Eager load everything needed for initial render
    @user = User.includes(
      :user_preference,
      :active_follows,
      :passive_follows,
      avatar_attachment: :blob
    ).find_by_friendly_or_id!(params[:id])
    
    # Check follow status if logged in
    @is_following = user_signed_in? ? 
      current_user.following?(@user) : false
    
    # Initial content load - only recent/visible items
    @recent_films_limit = 8
    @recent_photos_limit = 12
    
    # Load recent films with eager loading
    @recent_films = @user.films.published
      .includes(:film_riders, :film_filmers, video_attachment: :blob)
      .order(created_at: :desc)
      .limit(@recent_films_limit)
    
    # Load recent photos
    @recent_photos = @user.photos.published
      .includes(:album, image_attachment: :blob)
      .order(created_at: :desc)
      .limit(@recent_photos_limit)
    
    # Count totals for "View All" buttons
    @total_films_count = Rails.cache.fetch("user_#{@user.id}_films_count", expires_in: 5.minutes) do
      @user.films.published.count
    end
    
    @total_photos_count = Rails.cache.fetch("user_#{@user.id}_photos_count", expires_in: 5.minutes) do
      @user.photos.published.count
    end
    
    @total_albums_count = Rails.cache.fetch("user_#{@user.id}_albums_count", expires_in: 5.minutes) do
      @user.albums.published.count
    end
    
    # Stats for profile
    @followers_count = @user.passive_follows.count
    @following_count = @user.active_follows.count
    
    # Featured content (if any)
    @featured_film = @user.films.published
      .where(featured: true)
      .includes(video_attachment: :blob)
      .first
    
    # Activity stats
    load_activity_stats
    
    respond_to do |format|
      format.html
      format.json { render json: user_profile_json(@user) }
    end
  end
  
  def search_users
    # Fast autocomplete for user search
    query = params[:q]
    
    users = User.active
      .select(:id, :friendly_id, :username, :name)
      .search_by_fields(query, :username, :name)
      .limit(10)
    
    render json: users.map { |u|
      {
        id: u.friendly_id,
        username: u.username,
        name: u.name,
        url: user_path(u),
        avatar_url: u.avatar_thumbnail_url
      }
    }
  end
  
  # Load more films for user profile
  def user_films
    @user = User.find_by_friendly_or_id!(params[:id])
    offset = params[:offset].to_i
    limit = params[:limit].to_i.clamp(1, 24)
    
    @films = @user.films.published
      .includes(:film_riders, video_attachment: :blob)
      .order(created_at: :desc)
      .offset(offset)
      .limit(limit)
    
    render partial: 'films/film_cards', locals: { films: @films }
  end
  
  # Load more photos for user profile
  def user_photos
    @user = User.find_by_friendly_or_id!(params[:id])
    offset = params[:offset].to_i
    limit = params[:limit].to_i.clamp(1, 36)
    
    @photos = @user.photos.published
      .includes(:album, image_attachment: :blob)
      .order(created_at: :desc)
      .offset(offset)
      .limit(limit)
    
    render partial: 'photos/photo_grid', locals: { photos: @photos }
  end
  
  def following
    @user = User.find_by_friendly_or_id!(params[:id])
    @following = @user.following
      .includes(:user_preference, avatar_attachment: :blob)
      .page(params[:page])
      .per(30)
    
    respond_to do |format|
      format.html
      format.json { render json: @following }
    end
  end
  
  def followers
    @user = User.find_by_friendly_or_id!(params[:id])
    @followers = @user.followers
      .includes(:user_preference, avatar_attachment: :blob)
      .page(params[:page])
      .per(30)
    
    respond_to do |format|
      format.html  
      format.json { render json: @followers }
    end
  end
  
  private
  
  def set_user
    @user = User.find_by_friendly_or_id!(params[:id])
  end
  
  def apply_user_filters(scope)
    if params[:filter][:type].present?
      scope = scope.where(profile_type: params[:filter][:type])
    end
    
    if params[:filter][:has_content].present?
      scope = scope.having("films_count > 0 OR photos_count > 0")
    end
    
    scope
  end
  
  def apply_sort_order(scope)
    case params[:sort]
    when 'recent'
      scope.reorder(created_at: :desc)
    when 'active'
      scope.reorder(last_sign_in_at: :desc)
    when 'popular'
      scope.joins(:passive_follows)
        .group("users.id")
        .reorder("COUNT(follows.id) DESC")
    when 'content'
      scope.reorder("films_count DESC, photos_count DESC")
    else
      scope.order(created_at: :desc)
    end
  end
  
  def preload_user_stats(users)
    user_ids = users.map(&:id)
    
    # Batch load follower counts
    follower_counts = Follow.where(followed_id: user_ids)
      .group(:followed_id)
      .count
    
    # Batch load following counts
    following_counts = Follow.where(follower_id: user_ids)
      .group(:follower_id)
      .count
    
    # Already have films/photos counts from the query
    
    users.each do |user|
      user.instance_variable_set(:@followers_count, follower_counts[user.id] || 0)
      user.instance_variable_set(:@following_count, following_counts[user.id] || 0)
    end
  end
  
  def load_activity_stats
    # Load last 30 days of activity efficiently
    @activity_stats = Rails.cache.fetch("user_#{@user.id}_activity_stats", expires_in: 1.hour) do
      {
        films_uploaded: @user.films.where(created_at: 30.days.ago..).count,
        photos_uploaded: @user.photos.where(created_at: 30.days.ago..).count,
        comments_made: @user.comments.where(created_at: 30.days.ago..).count,
        favorites_given: @user.favorites.where(created_at: 30.days.ago..).count
      }
    end
  end
  
  def users_json_response(users)
    users.map do |user|
      {
        id: user.friendly_id,
        username: user.username,
        name: user.name,
        profile_type: user.profile_type,
        avatar_url: user.avatar_thumbnail_url,
        followers_count: user.instance_variable_get(:@followers_count) || 0,
        films_count: user.films_count,
        photos_count: user.photos_count
      }
    end
  end
  
  def user_profile_json(user)
    {
      id: user.friendly_id,
      username: user.username,
      name: user.name,
      bio: user.bio,
      profile_type: user.profile_type,
      location: user.location,
      website: user.website,
      joined: user.created_at,
      stats: {
        followers: @followers_count,
        following: @following_count,
        films: @total_films_count,
        photos: @total_photos_count,
        albums: @total_albums_count
      }
    }
  end
  
  def set_cache_headers
    if !user_signed_in?
      response.headers['Cache-Control'] = 'public, max-age=300'
      response.headers['Vary'] = 'Accept-Encoding'
    else
      response.headers['Cache-Control'] = 'private, max-age=60'
    end
  end
end
