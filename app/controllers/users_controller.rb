class UsersController < ApplicationController
  def index
    # Set cache headers for CDN (5 minutes for logged-out users)
    expires_in 5.minutes, public: true unless user_signed_in?

    @query = params[:q].to_s.strip
    @users = User.includes(avatar_attachment: :blob)
               .search_by_fields(@query, :username, :email)
               .order(Arel.sql("LOWER(username) ASC NULLS LAST"))
               .page(params[:page])
               .per(18)

    respond_to do |format|
      format.html
      format.json { render json: @users.select(:id, :username, :profile_type) }
    end
  end

  def show
    @user = User.find_by_friendly_or_id(params[:id])
    @query = params[:q].to_s.strip

    # Get all films and photos for the user (unpaginated ActiveRecord relations)
    @films = @user.all_films(viewing_user: current_user)
    @photos = @user.all_photos(viewing_user: current_user)

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
  end

  def following
    @user = User.find_by_friendly_or_id(params[:id])
    @query = params[:q].to_s.strip
    @users = @user.following
               .search_by_fields(@query, :username, :email)
               .order(Arel.sql("LOWER(username) ASC"))
    render 'index'
  end

  def followers
    @user = User.find_by_friendly_or_id(params[:id])
    @query = params[:q].to_s.strip
    @users = @user.followers
               .search_by_fields(@query, :username, :email)
               .order(Arel.sql("LOWER(username) ASC"))
    render 'index'
  end
end
