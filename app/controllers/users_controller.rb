class UsersController < ApplicationController
  def index
    # Set cache headers for CDN (5 minutes for logged-out users)
    unless user_signed_in?
      expires_in 5.minutes, public: true
      response.headers['Vary'] = 'Accept-Encoding'
    end

    @query = params[:q].to_s.strip

    # Base query with search
    base_query = User.search_by_fields(@query, :username, :email)
                     .order(Arel.sql("LOWER(username) ASC NULLS LAST"))

    # Apply profile_type filter if provided (for company autocomplete)
    if params[:profile_type].present?
      profile_types = params[:profile_type].to_s.split(',').map(&:strip)
      base_query = base_query.where(profile_type: profile_types)
    end

    respond_to do |format|
      format.html do
        @users = base_query.includes(avatar_attachment: :blob)
                          .page(params[:page])
                          .per(18)
        @has_more = @users.next_page.present?

        # Preload following status to avoid N+1 queries in profile cards
        if user_signed_in?
          user_ids = @users.map(&:id)
          @following_ids = current_user.active_follows.where(followed_id: user_ids).pluck(:followed_id).to_set
        else
          @following_ids = Set.new
        end

        # If it's an AJAX request for pagination, render just the profile cards
        if (request.xhr? || request.headers['X-Requested-With'] == 'XMLHttpRequest') && params[:page].present? && params[:page].to_i > 1
          render partial: 'profile_cards', locals: { users: @users, following_ids: @following_ids }, layout: false, content_type: 'text/html'
        else
          # Normal full page render
          render :index
        end
      end
      format.json do
        # For JSON autocomplete, return more results and simpler data
        users = base_query.limit(50)
                         .select(:id, :username, :profile_type)
                         .map { |u| { id: u.id, username: u.username, profile_type: u.profile_type } }
        render json: users
      end
    end
  end

  def show
    # Set cache headers for non-logged-in users (10 minutes)
    unless user_signed_in?
      expires_in 10.minutes, public: true
      response.headers['Vary'] = 'Accept-Encoding'
    end

    @user = User.includes(avatar_attachment: :blob).find_by_friendly_or_id(params[:id])
    @query = params[:q].to_s.strip

    # Get all films and photos for the user (unpaginated ActiveRecord relations)
    # Eager load associations to prevent N+1 queries
    @films = @user.all_films(viewing_user: current_user)
               .includes(:riders, :filmers, :companies, :company_user, :filmer_user, :editor_user, :film_reviews, thumbnail_attachment: :blob)
    @photos = @user.all_photos(viewing_user: current_user)
               .includes(:album, image_attachment: :blob)

    # Apply film type filter if present
    if params[:film_type].present?
      @films = @films.where(film_type: params[:film_type])
    end

    # Apply search BEFORE pagination if query present
    # This ensures we search across ALL content, not just the first page
    if @query.present?
      @films = @films.where("LOWER(title) LIKE ?", "%#{@query.downcase}%")
      @photos = @photos.where("LOWER(title) LIKE ?", "%#{@query.downcase}%")
    end

    # Apply sorting to films (use reorder to override any existing order)
    case params[:sort]
    when 'date_asc'
      @films = @films.reorder(release_date: :asc, created_at: :asc)
    when 'alpha_asc'
      @films = @films.reorder(Arel.sql("LOWER(title) ASC"))
    when 'alpha_desc'
      @films = @films.reorder(Arel.sql("LOWER(title) DESC"))
    else # date_desc (default)
      @films = @films.reorder(release_date: :desc, created_at: :desc)
    end

    # Paginate films and photos (3x6 = 18 per page)
    # Pagination happens AFTER search filtering
    @films = @films.page(params[:films_page]).per(18)
    @photos = @photos.page(params[:photos_page]).per(18)

    # Add variables for lazy loading support
    @films_total_count = @films.total_count
    @films_has_more = @films.next_page.present?
    @photos_total_count = @photos.total_count
    @photos_has_more = @photos.next_page.present?

    # Handle AJAX requests for lazy loading
    respond_to do |format|
      format.html do
        # If it's an AJAX request for pagination, render just the film or photo cards
        if (request.xhr? || request.headers['X-Requested-With'] == 'XMLHttpRequest') && params[:films_page].present? && params[:films_page].to_i > 1
          render partial: 'user_film_cards', locals: { films: @films, user: @user }, layout: false, content_type: 'text/html'
        elsif (request.xhr? || request.headers['X-Requested-With'] == 'XMLHttpRequest') && params[:photos_page].present? && params[:photos_page].to_i > 1
          render partial: 'user_photo_cards', locals: { photos: @photos, user: @user }, layout: false, content_type: 'text/html'
        else
          # Normal full page render
          render :show
        end
      end
    end
  end

  def following
    @user = User.find_by_friendly_or_id(params[:id])
    @query = params[:q].to_s.strip
    @users = @user.following
               .includes(avatar_attachment: :blob)
               .search_by_fields(@query, :username, :email)
               .order(Arel.sql("LOWER(username) ASC"))
               .page(params[:page])
               .per(18)
    @has_more = @users.next_page.present?

    # Preload following status to avoid N+1 queries
    if user_signed_in?
      user_ids = @users.map(&:id)
      @following_ids = current_user.active_follows.where(followed_id: user_ids).pluck(:followed_id).to_set
    else
      @following_ids = Set.new
    end

    render 'index'
  end

  def followers
    @user = User.find_by_friendly_or_id(params[:id])
    @query = params[:q].to_s.strip
    @users = @user.followers
               .includes(avatar_attachment: :blob)
               .search_by_fields(@query, :username, :email)
               .order(Arel.sql("LOWER(username) ASC"))
               .page(params[:page])
               .per(18)
    @has_more = @users.next_page.present?

    # Preload following status to avoid N+1 queries
    if user_signed_in?
      user_ids = @users.map(&:id)
      @following_ids = current_user.active_follows.where(followed_id: user_ids).pluck(:followed_id).to_set
    else
      @following_ids = Set.new
    end

    render 'index'
  end
end
