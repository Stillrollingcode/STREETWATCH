class FilmsController < ApplicationController
  before_action :set_film, only: [:show, :edit, :update, :destroy]
  before_action :authenticate_user!, except: [:index, :show]
  before_action :authorize_user!, only: [:edit, :update, :destroy]

  def index
    begin
      @films = Film.includes(:riders, :filmer_user, :editor_user, :company_user, thumbnail_attachment: :blob)

      # Only show published films to non-authenticated users
      # Authenticated users can see films they're tagged in or pending their approval
      unless user_signed_in?
        @films = @films.published
      else
        # Show published films + films user is tagged in or owns
        published_ids = Film.published.pluck(:id)
        user_approval_ids = current_user.film_approvals.pluck(:film_id)
        @films = @films.where(id: (published_ids + user_approval_ids).uniq)
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
           EXISTS (SELECT 1 FROM users WHERE users.id = films.filmer_user_id AND LOWER(COALESCE(users.username, '')) LIKE :q) OR
           EXISTS (SELECT 1 FROM users WHERE users.id = films.editor_user_id AND LOWER(COALESCE(users.username, '')) LIKE :q) OR
           EXISTS (SELECT 1 FROM users WHERE users.id = films.company_user_id AND LOWER(COALESCE(users.username, '')) LIKE :q)"
        )
      end

      # Apply sorting
      case params[:sort]
      when 'date_asc'
        @films = @films.select('DISTINCT films.*, COALESCE(films.release_date, films.created_at) AS sort_date')
                       .order(Arel.sql('sort_date ASC'))
      when 'date_desc', nil
        @films = @films.select('DISTINCT films.*, COALESCE(films.release_date, films.created_at) AS sort_date')
                       .order(Arel.sql('sort_date DESC'))
      when 'alpha_asc'
        @films = @films.select('DISTINCT films.*, LOWER(films.title) AS sort_title')
                       .order(Arel.sql('sort_title ASC'))
      when 'alpha_desc'
        @films = @films.select('DISTINCT films.*, LOWER(films.title) AS sort_title')
                       .order(Arel.sql('sort_title DESC'))
      end

      # Apply grouping
      if params[:group_by].present?
        # Determine group sort order (A-Z or Z-A)
        reverse_groups = params[:sort] == 'alpha_desc'

        case params[:group_by]
        when 'company'
          @grouped_films = @films.to_a.group_by { |f| (f.company_user&.username || f.company).presence || 'Unknown' }
          @grouped_films = @grouped_films.sort_by { |k, _| k.to_s.downcase }
          @grouped_films.reverse! if reverse_groups
          @grouped_films = @grouped_films.to_h
          # Sort films within each group by release date (newest first)
          @grouped_films.each { |_, films| films.sort_by! { |f| [f.release_date || Date.new(1900), f.created_at] }.reverse! }
        when 'filmer'
          @grouped_films = @films.to_a.group_by { |f| f.filmer_display_name.presence || 'Unknown' }
          @grouped_films = @grouped_films.sort_by { |k, _| k.to_s.downcase }
          @grouped_films.reverse! if reverse_groups
          @grouped_films = @grouped_films.to_h
          @grouped_films.each { |_, films| films.sort_by! { |f| [f.release_date || Date.new(1900), f.created_at] }.reverse! }
        when 'editor'
          @grouped_films = @films.to_a.group_by { |f| f.editor_display_name.presence || 'Unknown' }
          @grouped_films = @grouped_films.sort_by { |k, _| k.to_s.downcase }
          @grouped_films.reverse! if reverse_groups
          @grouped_films = @grouped_films.to_h
          @grouped_films.each { |_, films| films.sort_by! { |f| [f.release_date || Date.new(1900), f.created_at] }.reverse! }
        end
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
      rider_ids: []
    )
  end
end
