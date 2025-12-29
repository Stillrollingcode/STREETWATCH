class FilmsController < ApplicationController
  before_action :set_film, only: [:show, :edit, :update, :destroy, :hide_from_profile, :unhide_from_profile]
  before_action :increment_views, only: [:show]
  before_action :authenticate_user!, except: [:index, :show]
  before_action :authorize_user!, only: [:edit, :update, :destroy]

  def index
    # Set cache headers for CDN (5 minutes for logged-out users)
    expires_in 5.minutes, public: true unless user_signed_in?

    begin
      @films = Film.includes(:riders, :filmers, :companies, :filmer_user, :editor_user, :company_user, thumbnail_attachment: :blob)

      # Only show published films to non-authenticated users
      # Authenticated users can see films they're tagged in or pending their approval
      if user_signed_in?
        # Show published films + films user is tagged in
        @films = @films.where(
          "films.id NOT IN (
            SELECT film_id FROM film_approvals
            WHERE film_approvals.status = 'pending'
            GROUP BY film_id
          )
          OR films.id IN (SELECT film_id FROM film_riders WHERE user_id = ?)",
          current_user.id
        ).distinct
      else
        # Only published films for non-authenticated users
        @films = @films.where(
          "films.id NOT IN (
            SELECT film_id FROM film_approvals
            WHERE film_approvals.status = 'pending'
            GROUP BY film_id
          )"
        )
      end







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

      # Apply sorting
      case params[:sort]
      when 'date_asc'
        @films = @films.select('films.*, COALESCE(films.release_date, films.created_at) AS sort_date')
                       .order(Arel.sql('sort_date ASC'))
                       .distinct
      when 'date_desc', nil
        @films = @films.select('films.*, COALESCE(films.release_date, films.created_at) AS sort_date')
                       .order(Arel.sql('sort_date DESC'))
                       .distinct
      when 'alpha_asc'
        @films = @films.select('films.*, LOWER(films.title) AS sort_title')
                       .order(Arel.sql('sort_title ASC'))
                       .distinct
      when 'alpha_desc'
        @films = @films.select('films.*, LOWER(films.title) AS sort_title')
                       .order(Arel.sql('sort_title DESC'))
                       .distinct
      end

      # Apply grouping (limit to 200 records for performance)
      if params[:group_by].present?
        # Limit results before grouping to improve performance
        films_to_group = @films.limit(200).to_a

        # Determine group sort order (A-Z or Z-A)
        reverse_groups = params[:sort] == 'alpha_desc'

        case params[:group_by]
        when 'company'
          # Group by company, handling multiple companies per film
          @grouped_films = Hash.new { |h, k| h[k] = [] }
          films_to_group.each do |film|
            company_names = film.companies_display_names
            if company_names.any?
              company_names.each { |name| @grouped_films[name] << film }
            else
              @grouped_films['Unknown'] << film
            end
          end
          @grouped_films = @grouped_films.sort_by { |k, _| k.to_s.downcase }
          @grouped_films.reverse! if reverse_groups
          @grouped_films = @grouped_films.to_h
          # Sort films within each group by release date (newest first)
          @grouped_films.each { |_, films| films.sort_by! { |f| [f.release_date || Date.new(1900), f.created_at] }.reverse! }
        when 'filmer'
          # Group by filmer, handling multiple filmers per film
          @grouped_films = Hash.new { |h, k| h[k] = [] }
          films_to_group.each do |film|
            filmer_names = film.filmers_display_names
            if filmer_names.any?
              filmer_names.each { |name| @grouped_films[name] << film }
            else
              @grouped_films['Unknown'] << film
            end
          end
          @grouped_films = @grouped_films.sort_by { |k, _| k.to_s.downcase }
          @grouped_films.reverse! if reverse_groups
          @grouped_films = @grouped_films.to_h
          @grouped_films.each { |_, films| films.sort_by! { |f| [f.release_date || Date.new(1900), f.created_at] }.reverse! }
        when 'editor'
          @grouped_films = films_to_group.group_by { |f| f.editor_display_name.presence || 'Unknown' }
          @grouped_films = @grouped_films.sort_by { |k, _| k.to_s.downcase }
          @grouped_films.reverse! if reverse_groups
          @grouped_films = @grouped_films.to_h
          @grouped_films.each { |_, films| films.sort_by! { |f| [f.release_date || Date.new(1900), f.created_at] }.reverse! }
        end
      else
        # Paginate to 18 films per page (3 columns × 6 rows) when not grouping
        @films = @films.page(params[:page]).per(18)
      end
    rescue => e
      Rails.logger.error "Films index error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Fallback to simple query
      @films = Film.includes(thumbnail_attachment: :blob)
                   .order(Arel.sql('COALESCE(films.release_date, films.created_at) DESC'))

      flash.now[:alert] = "There was an error with your search. Showing all films instead."
    end
  end

  def show
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
    @film = Film.find_by_friendly_or_id(params[:id])
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
    params.require(:film).permit(
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
  end

  def increment_views
    @film.increment!(:views_count)
  end
end
