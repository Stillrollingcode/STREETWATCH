class FilmsController < ApplicationController
  before_action :set_film, only: [:show, :edit, :update, :destroy, :hide_from_profile, :unhide_from_profile]
  before_action :increment_views, only: [:show]
  before_action :authenticate_user!, except: [:index, :show]
  before_action :authorize_user!, only: [:edit, :update, :destroy]

  def index
    # Set cache headers for CDN (5 minutes for logged-out users)
    unless user_signed_in?
      expires_in 5.minutes, public: true
      response.headers['Cache-Control'] = 'public, max-age=300, must-revalidate'
      response.headers['Vary'] = 'Cookie, Accept-Encoding'
    end

    begin
      # Start with base query and default sorting (newest release date first)
      @films = Film.order(Arel.sql('COALESCE(films.release_date, films.created_at) DESC'))

      # Apply film type filter
      if params[:film_type].present?
        @films = @films.where(film_type: params[:film_type])
      end

      # Apply search filter using Searchable concern
      if params[:q].present?
        @films = @films.search_with_sql(
          params[:q],
          # PostgreSQL version
          "films.title ILIKE :q OR
           COALESCE(films.company, '') ILIKE :q OR
           COALESCE(films.description, '') ILIKE :q OR
           COALESCE(films.custom_filmer_name, '') ILIKE :q OR
           COALESCE(films.custom_editor_name, '') ILIKE :q OR
           COALESCE(films.custom_riders, '') ILIKE :q OR
           EXISTS (
             SELECT 1 FROM film_riders
             JOIN users ON users.id = film_riders.user_id
             WHERE film_riders.film_id = films.id AND COALESCE(users.username, '') ILIKE :q
           ) OR
           EXISTS (
             SELECT 1 FROM film_filmers
             JOIN users ON users.id = film_filmers.user_id
             WHERE film_filmers.film_id = films.id AND COALESCE(users.username, '') ILIKE :q
           ) OR
           EXISTS (
             SELECT 1 FROM film_companies
             JOIN users ON users.id = film_companies.user_id
             WHERE film_companies.film_id = films.id AND COALESCE(users.username, '') ILIKE :q
           ) OR
           EXISTS (SELECT 1 FROM users WHERE users.id = films.filmer_user_id AND COALESCE(users.username, '') ILIKE :q) OR
           EXISTS (SELECT 1 FROM users WHERE users.id = films.editor_user_id AND COALESCE(users.username, '') ILIKE :q) OR
           EXISTS (SELECT 1 FROM users WHERE users.id = films.company_user_id AND COALESCE(users.username, '') ILIKE :q)",
          # SQLite version
          "LOWER(films.title) LIKE :q OR
           LOWER(COALESCE(films.company, '')) LIKE :q OR
           LOWER(COALESCE(films.description, '')) LIKE :q OR
           LOWER(COALESCE(films.custom_filmer_name, '')) LIKE :q OR
           LOWER(COALESCE(films.custom_editor_name, '')) LIKE :q OR
           LOWER(COALESCE(films.custom_riders, '')) LIKE :q OR
           EXISTS (
             SELECT 1 FROM film_riders
             JOIN users ON users.id = film_riders.user_id
             WHERE film_riders.film_id = films.id AND LOWER(COALESCE(users.username, '')) LIKE :q
           ) OR
           EXISTS (
             SELECT 1 FROM film_filmers
             JOIN users ON users.id = film_filmers.user_id
             WHERE film_filmers.film_id = films.id AND LOWER(COALESCE(users.username, '')) LIKE :q
           ) OR
           EXISTS (
             SELECT 1 FROM film_companies
             JOIN users ON users.id = film_companies.user_id
             WHERE film_companies.film_id = films.id AND LOWER(COALESCE(users.username, '')) LIKE :q
           ) OR
           EXISTS (SELECT 1 FROM users WHERE users.id = films.filmer_user_id AND LOWER(COALESCE(users.username, '')) LIKE :q) OR
           EXISTS (SELECT 1 FROM users WHERE users.id = films.editor_user_id AND LOWER(COALESCE(users.username, '')) LIKE :q) OR
           EXISTS (SELECT 1 FROM users WHERE users.id = films.company_user_id AND LOWER(COALESCE(users.username, '')) LIKE :q)"
        )
      end

      # Apply sorting (override default if specified)
      if params[:sort].present?
        case params[:sort]
        when 'date_asc'
          @films = @films.reorder(Arel.sql('COALESCE(films.release_date, films.created_at) ASC'))
        when 'date_desc'
          @films = @films.reorder(Arel.sql('COALESCE(films.release_date, films.created_at) DESC'))
        when 'alpha_asc'
          @films = @films.reorder(Arel.sql('LOWER(films.title) ASC'))
        when 'alpha_desc'
          @films = @films.reorder(Arel.sql('LOWER(films.title) DESC'))
        end
      end

      # Apply grouping or pagination
      if params[:group_by].present?
        # Limit to 200 records before grouping, then eager load
        films_to_group = @films.limit(200)
                               .includes(:riders, :filmers, :companies, :filmer_user, :editor_user, :company_user, :film_reviews, thumbnail_attachment: :blob)
                               .to_a

        # Determine group sort order (A-Z or Z-A)
        reverse_groups = params[:sort] == 'alpha_desc'

        case params[:group_by]
        when 'company'
          # Group by company, handling multiple companies per film
          temp_groups = Hash.new { |h, k| h[k] = { user: nil, films: [], total_count: 0 } }
          films_to_group.each do |film|
            # Get company users (not just names)
            companies = film.companies.presence || []
            if companies.any?
              companies.each do |company_user|
                temp_groups[company_user.username][:user] = company_user
                temp_groups[company_user.username][:films] << film
              end
            else
              # Handle legacy company field or unknown
              company_name = film.company_user&.username || film.company.presence || 'Unknown'
              temp_groups[company_name][:films] << film
              temp_groups[company_name][:user] = film.company_user if film.company_user
            end
          end
          # Sort groups and limit films to first 5
          @grouped_films = temp_groups.sort_by { |k, _| k.to_s.downcase }
          @grouped_films.reverse! if reverse_groups
          @grouped_films = @grouped_films.to_h
          @grouped_films.each do |_, data|
            data[:films].sort_by! { |f| [f.release_date || Date.new(1900), f.created_at] }.reverse!
            data[:total_count] = data[:films].count
            data[:films] = data[:films].first(5)
          end
        when 'filmer'
          # Group by filmer, handling multiple filmers per film
          temp_groups = Hash.new { |h, k| h[k] = { user: nil, films: [], total_count: 0 } }
          films_to_group.each do |film|
            # Get filmer users (not just names)
            filmers = film.filmers.presence || []
            if filmers.any?
              filmers.each do |filmer_user|
                temp_groups[filmer_user.username][:user] = filmer_user
                temp_groups[filmer_user.username][:films] << film
              end
            else
              # Handle legacy filmer_user field or unknown
              filmer_name = film.filmer_user&.username || film.custom_filmer_name.presence || 'Unknown'
              temp_groups[filmer_name][:films] << film
              temp_groups[filmer_name][:user] = film.filmer_user if film.filmer_user
            end
          end
          # Sort groups and limit films to first 5
          @grouped_films = temp_groups.sort_by { |k, _| k.to_s.downcase }
          @grouped_films.reverse! if reverse_groups
          @grouped_films = @grouped_films.to_h
          @grouped_films.each do |_, data|
            data[:films].sort_by! { |f| [f.release_date || Date.new(1900), f.created_at] }.reverse!
            data[:total_count] = data[:films].count
            data[:films] = data[:films].first(5)
          end
        when 'editor'
          temp_groups = Hash.new { |h, k| h[k] = { user: nil, films: [], total_count: 0 } }
          films_to_group.each do |film|
            editor_name = film.editor_display_name.presence || 'Unknown'
            temp_groups[editor_name][:user] = film.editor_user
            temp_groups[editor_name][:films] << film
          end
          # Sort groups and limit films to first 5
          @grouped_films = temp_groups.sort_by { |k, _| k.to_s.downcase }
          @grouped_films.reverse! if reverse_groups
          @grouped_films = @grouped_films.to_h
          @grouped_films.each do |_, data|
            data[:films].sort_by! { |f| [f.release_date || Date.new(1900), f.created_at] }.reverse!
            data[:total_count] = data[:films].count
            data[:films] = data[:films].first(5)
          end
        end
      else
        # Paginate first, then eager load only the 18 films needed
        @films = @films.page(params[:page]).per(18)
                       .includes(:riders, :filmers, :companies, :company_user, :filmer_user, :editor_user, :film_reviews, thumbnail_attachment: :blob)

        # Add variables for lazy loading support
        @total_count = @films.total_count
        @has_more = @films.next_page.present?
      end
    rescue => e
      Rails.logger.error "Films index error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Fallback to simple query
      @films = Film.order(created_at: :desc)
                   .page(params[:page]).per(18)
                   .includes(:film_reviews, thumbnail_attachment: :blob)

      flash.now[:alert] = "There was an error with your search. Showing all films instead."
    end

    # Handle AJAX requests for lazy loading
    respond_to do |format|
      format.html do
        # If it's an AJAX request for pagination, render just the film cards
        # Check for X-Requested-With header (set by lazy_load_controller.js)
        if (request.xhr? || request.headers['X-Requested-With'] == 'XMLHttpRequest') && params[:page].present? && params[:page].to_i > 1
          render partial: 'film_cards', locals: { films: @films }, layout: false, content_type: 'text/html'
        else
          # Normal full page render
          render :index
        end
      end
    end
  end

  def show
    # Set cache headers for non-logged-in users (10 minutes)
    unless user_signed_in?
      expires_in 10.minutes, public: true
      response.headers['Vary'] = 'Accept-Encoding'
    end

    # Check if film is published or user has access
    unless @film.published? || can_view_unpublished?(@film)
      flash[:alert] = "This film is pending approval and cannot be viewed yet."
      redirect_to films_path
    end
  end

  def new
    @film = Film.new
  end

  def create
    @film = Film.new(film_params)
    @film.user = current_user

    if @film.save
      # Auto-tag company/crew accounts as companies on their uploads (after save)
      if current_user.profile_type.in?(['company', 'crew'])
        unless @film.companies.include?(current_user)
          @film.companies << current_user
          # The approval will be auto-created and auto-approved by the after_commit callback
        end
      end

      redirect_to @film, notice: "Film was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @film
  end

  def update
    if @film.update(film_params)
      redirect_to @film, notice: "Film was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @film.destroy
    redirect_to films_url, notice: "Film was successfully deleted."
  end

  def hide_from_profile
    current_user.hide_film_from_profile(@film)
    respond_to do |format|
      format.html { redirect_to user_path(current_user), notice: "Film hidden from your profile." }
      format.turbo_stream
    end
  end

  def unhide_from_profile
    current_user.unhide_film_from_profile(@film)
    respond_to do |format|
      format.html { redirect_to user_path(current_user), notice: "Film restored to your profile." }
      format.turbo_stream
    end
  end

  private

  def set_film
    @film = Film.includes(
      :riders, :filmers, :companies, :filmer_user, :editor_user, :company_user,
      :film_approvals, :favorites,
      comments: [:user, replies: :user], # Eager load comment associations
      thumbnail_attachment: :blob,
      video_attachment: :blob
    ).find_by_friendly_or_id(params[:id])
  end

  def can_view_unpublished?(film)
    return false unless user_signed_in?

    # User is tagged in the film
    film.tagged_users.include?(current_user)
  end

  def authorize_user!
    # Only allow the user who uploaded the film to edit/delete it
    unless @film.user_id == current_user.id
      flash[:alert] = "You are not authorized to perform this action."
      redirect_to films_path
    end
  end

  def film_params
    permitted_params = params.require(:film).permit(
      :title,
      :description,
      :release_date,
      :filmer_user_id,
      :custom_filmer_name,
      :editor_user_id,
      :custom_editor_name,
      :custom_riders,
      :company,
      :company_user_id,
      :runtime,
      :music_featured,
      :thumbnail,
      :video,
      :youtube_url,
      :film_type,
      :parent_film_title,
      :aspect_ratio,
      rider_ids: [],
      filmer_ids: [],
      company_ids: []
    )

    # Clean up arrays - remove empty strings and ensure proper format
    # When form sends [""] to clear associations, convert to []
    [:rider_ids, :filmer_ids, :company_ids].each do |key|
      if permitted_params[key].present?
        permitted_params[key] = permitted_params[key].reject(&:blank?).map(&:to_i)
      end
    end

    permitted_params
  end

  def increment_views
    # Use background job to avoid blocking the request
    IncrementViewCountJob.perform_later(@film.id)
  end
end
