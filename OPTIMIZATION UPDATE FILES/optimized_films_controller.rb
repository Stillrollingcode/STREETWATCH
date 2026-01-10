# app/controllers/films_controller.rb
# Optimized version with lazy loading and query optimization

class FilmsController < ApplicationController
  before_action :authenticate_user!, except: [:index, :show, :search_films]
  before_action :set_film, only: [:show, :edit, :update, :destroy]
  
  # Cache film counts and basic data for 5 minutes
  before_action :set_cache_headers, only: [:index, :show]

  def index
    # Initial load - only what's visible above the fold (12-16 films)
    @initial_load_count = 16
    
    # Build base query with eager loading to prevent N+1 queries
    films_base = Film.published
      .includes(
        :user,
        :film_riders => :rider,
        :film_filmers => :filmer,
        :film_companies => :company,
        video_attachment: :blob,
        thumbnail_attachment: :blob
      )
    
    # Apply filters if present
    if params[:filter].present?
      films_base = apply_filters(films_base)
    end
    
    # Apply search if present
    if params[:query].present?
      films_base = films_base.search_by_fields(
        params[:query], 
        :title, :description, :year
      )
    end
    
    # Sort order with database indexes
    films_base = films_base.order(created_at: :desc)
    
    # For initial page load - load only visible films
    if request.format.html? && !params[:page]
      @films = films_base.limit(@initial_load_count)
      @total_count = films_base.count
      @has_more = @total_count > @initial_load_count
    else
      # For pagination requests (AJAX/Turbo)
      @films = films_base.page(params[:page]).per(24)
    end
    
    # Preload aggregated data to avoid N+1
    preload_film_stats(@films) if @films.any?
    
    respond_to do |format|
      format.html do
        if params[:page]
          # Return only the film cards for infinite scroll
          render partial: 'films/film_cards', locals: { films: @films }
        else
          render :index
        end
      end
      format.json { render json: film_json_response(@films) }
    end
  end

  def show
    # Eager load all associations needed for the page
    @film = Film.includes(
      :user,
      :film_riders => { rider: [:user_preference] },
      :film_filmers => { filmer: [:user_preference] },
      :film_companies => { company: [:user_preference] },
      :film_approvals,
      comments: [:user, replies: :user],
      video_attachment: :blob,
      video_qualities_attachments: :blob
    ).find_by_friendly_or_id!(params[:id])
    
    # Load view count asynchronously
    IncrementViewCountJob.perform_later(@film.id) if user_signed_in?
    
    # Lazy load related content
    @related_films_count = 6
    
    # Only load visible comments initially
    @initial_comments = @film.comments
      .includes(:user, replies: :user)
      .where(parent_id: nil)
      .order(created_at: :desc)
      .limit(10)
    
    @total_comments_count = @film.comments.count
    @has_more_comments = @total_comments_count > 10
    
    # Track if current user has favorited
    @is_favorited = user_signed_in? ? 
      current_user.favorites.exists?(film: @film) : false
    
    # Cache the film page for non-logged-in users
    if !user_signed_in?
      expires_in 10.minutes, public: true
    end
    
    respond_to do |format|
      format.html
      format.json { render json: detailed_film_json(@film) }
    end
  end
  
  def search_films
    # Autocomplete search - optimized for speed
    query = params[:q]
    
    films = Film.published
      .select(:id, :friendly_id, :title, :year)
      .search_by_fields(query, :title)
      .limit(10)
    
    render json: films.map { |f| 
      { 
        id: f.friendly_id, 
        title: f.title,
        year: f.year,
        url: film_path(f)
      } 
    }
  end
  
  # Lazy load more films for infinite scroll
  def load_more
    offset = params[:offset].to_i
    limit = params[:limit].to_i.clamp(1, 50)
    
    films = Film.published
      .includes(:user, :film_riders, video_attachment: :blob)
      .order(created_at: :desc)
      .offset(offset)
      .limit(limit)
    
    render partial: 'films/film_cards', locals: { films: films }
  end
  
  # Lazy load related films
  def related
    @film = Film.find_by_friendly_or_id!(params[:id])
    
    # Find related films by shared riders/filmers
    rider_ids = @film.film_riders.pluck(:rider_id)
    filmer_ids = @film.film_filmers.pluck(:filmer_id)
    
    @related_films = Film.published
      .joins("LEFT JOIN film_riders fr ON fr.film_id = films.id")
      .joins("LEFT JOIN film_filmers ff ON ff.film_id = films.id")
      .where("fr.rider_id IN (?) OR ff.filmer_id IN (?)", rider_ids, filmer_ids)
      .where.not(id: @film.id)
      .select("films.*, COUNT(DISTINCT fr.rider_id) + COUNT(DISTINCT ff.filmer_id) as relevance_score")
      .group("films.id")
      .order("relevance_score DESC")
      .limit(6)
      .includes(:user, video_attachment: :blob)
    
    render partial: 'films/related_films', locals: { films: @related_films }
  end
  
  private
  
  def set_film
    @film = Film.find_by_friendly_or_id!(params[:id])
  end
  
  def apply_filters(scope)
    scope = scope.where(year: params[:filter][:year]) if params[:filter][:year].present?
    scope = scope.where(film_type: params[:filter][:type]) if params[:filter][:type].present?
    scope = scope.joins(:film_riders).where(film_riders: { rider_id: params[:filter][:rider_id] }) if params[:filter][:rider_id].present?
    scope = scope.joins(:film_filmers).where(film_filmers: { filmer_id: params[:filter][:filmer_id] }) if params[:filter][:filmer_id].present?
    scope
  end
  
  def preload_film_stats(films)
    # Batch load counts to avoid N+1
    film_ids = films.map(&:id)
    
    # Preload comment counts
    comment_counts = Comment.where(film_id: film_ids)
      .group(:film_id)
      .count
    
    # Preload favorite counts  
    favorite_counts = Favorite.where(film_id: film_ids)
      .group(:film_id)
      .count
    
    # Attach counts to films
    films.each do |film|
      film.instance_variable_set(:@comment_count, comment_counts[film.id] || 0)
      film.instance_variable_set(:@favorite_count, favorite_counts[film.id] || 0)
    end
  end
  
  def film_json_response(films)
    films.map do |film|
      {
        id: film.friendly_id,
        title: film.title,
        year: film.year,
        thumbnail_url: film.thumbnail_url,
        user: film.user.username,
        comment_count: film.instance_variable_get(:@comment_count) || 0,
        favorite_count: film.instance_variable_get(:@favorite_count) || 0
      }
    end
  end
  
  def detailed_film_json(film)
    {
      id: film.friendly_id,
      title: film.title,
      description: film.description,
      year: film.year,
      video_url: film.video_url,
      qualities: film.available_qualities,
      riders: film.film_riders.map { |fr| 
        { id: fr.rider.friendly_id, name: fr.rider.username }
      },
      filmers: film.film_filmers.map { |ff|
        { id: ff.filmer.friendly_id, name: ff.filmer.username }
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
