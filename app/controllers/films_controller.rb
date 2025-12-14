class FilmsController < ApplicationController
  before_action :set_film, only: [:show, :edit, :update, :destroy]
  before_action :authenticate_user!, except: [:index, :show]

  def index
    @films = Film.includes(:riders, :filmer_user, :editor_user, thumbnail_attachment: :blob)

    # Apply film type filter
    if params[:film_type].present?
      @films = @films.where(film_type: params[:film_type])
    end

    # Apply search filter
    if params[:q].present?
      query = "%#{params[:q]}%"
      @films = @films.left_joins(:riders, :filmer_user, :editor_user)

      # Use ILIKE for PostgreSQL, LIKE with LOWER() for SQLite
      if ActiveRecord::Base.connection.adapter_name.downcase == 'postgresql'
        @films = @films.where(
          "films.title ILIKE ? OR films.company ILIKE ? OR films.description ILIKE ? OR
           films.custom_filmer_name ILIKE ? OR films.custom_editor_name ILIKE ? OR
           users.username ILIKE ? OR filmer_users_films.username ILIKE ? OR editor_users_films.username ILIKE ?",
          query, query, query, query, query, query, query, query
        ).distinct
      else
        # SQLite fallback
        lower_query = "%#{params[:q].downcase}%"
        @films = @films.where(
          "LOWER(films.title) LIKE ? OR LOWER(films.company) LIKE ? OR LOWER(films.description) LIKE ? OR
           LOWER(films.custom_filmer_name) LIKE ? OR LOWER(films.custom_editor_name) LIKE ? OR
           LOWER(users.username) LIKE ? OR LOWER(filmer_users_films.username) LIKE ? OR LOWER(editor_users_films.username) LIKE ?",
          lower_query, lower_query, lower_query, lower_query, lower_query, lower_query, lower_query, lower_query
        ).distinct
      end
    end

    # Apply sorting
    case params[:sort]
    when 'date_asc'
      @films = @films.order(Arel.sql('COALESCE(films.release_date, films.created_at) ASC'))
    when 'date_desc', nil
      @films = @films.order(Arel.sql('COALESCE(films.release_date, films.created_at) DESC'))
    when 'alpha_asc'
      @films = @films.order('LOWER(films.title) ASC')
    when 'alpha_desc'
      @films = @films.order('LOWER(films.title) DESC')
    end

    # Apply grouping
    if params[:group_by].present?
      # Determine group sort order (A-Z or Z-A)
      reverse_groups = params[:sort] == 'alpha_desc'

      case params[:group_by]
      when 'company'
        @grouped_films = @films.group_by { |f| f.company.presence || 'Unknown' }
        @grouped_films = @grouped_films.sort_by { |k, _| k.downcase }
        @grouped_films.reverse! if reverse_groups
        @grouped_films = @grouped_films.to_h
        # Sort films within each group by release date (newest first)
        @grouped_films.each { |_, films| films.sort_by! { |f| [f.release_date || Date.new(1900), f.created_at] }.reverse! }
      when 'filmer'
        @grouped_films = @films.group_by { |f| f.filmer_display_name.presence || 'Unknown' }
        @grouped_films = @grouped_films.sort_by { |k, _| k.downcase }
        @grouped_films.reverse! if reverse_groups
        @grouped_films = @grouped_films.to_h
        @grouped_films.each { |_, films| films.sort_by! { |f| [f.release_date || Date.new(1900), f.created_at] }.reverse! }
      when 'editor'
        @grouped_films = @films.group_by { |f| f.editor_display_name.presence || 'Unknown' }
        @grouped_films = @grouped_films.sort_by { |k, _| k.downcase }
        @grouped_films.reverse! if reverse_groups
        @grouped_films = @grouped_films.to_h
        @grouped_films.each { |_, films| films.sort_by! { |f| [f.release_date || Date.new(1900), f.created_at] }.reverse! }
      end
    end
  end

  def show
    @film
  end

  def new
    @film = Film.new
  end

  def create
    @film = Film.new(film_params)

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
    @film = Film.find(params[:id])
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
