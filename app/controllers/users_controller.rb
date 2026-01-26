class UsersController < ApplicationController
  def index
    # Set cache headers for CDN (5 minutes for logged-out users)
    unless user_signed_in?
      expires_in 5.minutes, public: true
      response.headers['Vary'] = 'Accept-Encoding'
    end

    @query = params[:q].to_s.strip

    # Base query with search
    base_query = User.search_by_fields(@query, :username, :email, :name)
    base_query = apply_user_filters(base_query)
    base_query = apply_user_sort(base_query)

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
                         .select(:id, :username, :name, :profile_type)
                         .map { |u| { id: u.id, username: u.username, name: u.name, profile_type: u.profile_type } }
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

    # Minimal user load with only avatar - counts will use cached columns
    @user = User.includes({ avatar_attachment: :blob }, :preference).find_by_friendly_or_id(params[:id])
    @query = params[:q].to_s.strip

    # Preload counts from counter cache columns
    @followers_count = @user.followers_count
    @following_count = @user.following_count

    # Preload approved sponsors (usually 0-5, small list)
    sponsors_ttl = user_signed_in? ? 2.minutes : 10.minutes
    @approved_sponsors = fetch_user_cache("approved_sponsors:v1", expires_in: sponsors_ttl) do
      @user.approved_sponsors.includes(avatar_attachment: :blob).to_a
    end

    # Preload data for logged-in user viewing profiles
    # This prevents multiple queries in the view template
    @is_own_profile = user_signed_in? && current_user.id == @user.id
    if @is_own_profile
      # Own profile: preload pending approval counts
      @pending_film_approvals = current_user.film_approvals.pending.count
      @pending_photo_approvals = current_user.photo_approvals.pending.count
      @pending_sponsor_approvals = current_user.company_type? ? current_user.sponsored_by_approvals.pending.count : 0
      @is_following = false
      @notification_setting = nil
    elsif user_signed_in?
      # Viewing someone else's profile: preload follow status and notification settings
      @pending_film_approvals = 0
      @pending_photo_approvals = 0
      @pending_sponsor_approvals = 0
      @is_following = current_user.following?(@user)
      @notification_setting = current_user.profile_notification_settings.find_by(target_user: @user)
    else
      # Not logged in
      @pending_film_approvals = 0
      @pending_photo_approvals = 0
      @pending_sponsor_approvals = 0
      @is_following = false
      @notification_setting = nil
    end

    # Only load films/photos for the ACTIVE tab (determined by preference or default)
    ordered_tabs = @user.preference&.ordered_tabs || ["films", "photos", "articles"]
    @active_tab = ordered_tabs.first

    # For initial page load: only load data for the first visible tab
    # Other tabs will load via Turbo Frames when clicked
    @films = nil
    @photos = nil
    @films_has_more = false
    @photos_has_more = false

    if @active_tab == 'films' || params[:films_page].present?
      load_films_data
    end

    if @active_tab == 'photos' || params[:photos_page].present?
      load_photos_data
    end

    # Handle AJAX requests for lazy loading
    respond_to do |format|
      format.html do
        # If it's an AJAX request for pagination, render just the film or photo cards
        if (request.xhr? || request.headers['X-Requested-With'] == 'XMLHttpRequest') && params[:films_page].present? && params[:films_page].to_i > 1
          load_films_data unless @films
          render partial: 'user_film_cards', locals: { films: @films, user: @user }, layout: false, content_type: 'text/html'
        elsif (request.xhr? || request.headers['X-Requested-With'] == 'XMLHttpRequest') && params[:photos_page].present? && params[:photos_page].to_i > 1
          load_photos_data unless @photos
          render partial: 'user_photo_cards', locals: { photos: @photos, user: @user }, layout: false, content_type: 'text/html'
        else
          # Normal full page render
          render :show
        end
      end
    end
  end

  # Turbo Frame endpoint for loading tab content lazily
  def tab_content
    @user = User.find_by_friendly_or_id(params[:id])
    @query = params[:q].to_s.strip
    tab = params[:tab]

    case tab
    when 'films'
      load_films_data
      render partial: 'users/tabs/films_content', locals: { user: @user, films: @films, films_has_more: @films_has_more, query: @query }
    when 'photos'
      load_photos_data
      render partial: 'users/tabs/photos_content', locals: { user: @user, photos: @photos, photos_has_more: @photos_has_more, query: @query }
    when 'articles'
      render partial: 'users/tabs/articles_content', locals: { user: @user }
    else
      head :not_found
    end
  end

  # Endpoint for loading film sub-tab content (as-rider, as-filmer, etc.)
  def film_subtab_content
    @user = User.find_by_friendly_or_id(params[:id])
    subtab = params[:subtab]

    case subtab
    when 'as-rider'
      @films = @user.rider_films.published.includes(thumbnail_attachment: :blob).recent
      render partial: 'users/subtabs/role_films', locals: { films: @films, role: 'Rider', user: @user }
    when 'as-filmer'
      @films = (@user.filmer_films.published + @user.filmed_films.published).uniq
      render partial: 'users/subtabs/role_films', locals: { films: @films, role: 'Filmer', user: @user }
    when 'as-editor'
      @films = @user.edited_films.published.includes(thumbnail_attachment: :blob).recent
      render partial: 'users/subtabs/role_films', locals: { films: @films, role: 'Editor', user: @user }
    when 'playlists'
      playlists = @user.playlists.includes(films: { thumbnail_attachment: :blob }).order(created_at: :desc)
      playlists = playlists.where(is_public: true) unless user_signed_in? && current_user.id == @user.id
      render partial: 'users/subtabs/playlists', locals: { playlists: playlists, user: @user }
    when 'favorites'
      favorites_name = @user.company_type? ? "Brand Highlights" : "#{@user.username}'s Favorite Projects"
      playlist = @user.playlists.find_or_create_by(name: favorites_name) do |p|
        p.description = @user.company_type? ? "Highlighted projects" : "Favorite films"
        p.is_public = true
      end
      render partial: 'users/subtabs/favorites', locals: { playlist: playlist, user: @user }
    when 'pending-films'
      films = Film.where(user_id: @user.id)
                  .joins(:film_approvals)
                  .where(film_approvals: { status: 'pending' })
                  .distinct
                  .includes(thumbnail_attachment: :blob)
      render partial: 'users/subtabs/pending_films', locals: { films: films, user: @user }
    when 'hidden-films'
      films = @user.hidden_films_from_profile.includes(thumbnail_attachment: :blob)
      render partial: 'users/subtabs/hidden_films', locals: { films: films, user: @user }
    else
      head :not_found
    end
  end

  # Endpoint for loading photo sub-tab content (albums, pending, hidden)
  def photo_subtab_content
    @user = User.find_by_friendly_or_id(params[:id])
    subtab = params[:subtab]
    is_own_profile = user_signed_in? && current_user.id == @user.id

    case subtab
    when 'albums'
      albums = @user.albums.includes(photos: :image_attachment).order(created_at: :desc)
      albums = albums.where(is_public: true) unless is_own_profile
      render partial: 'users/subtabs/albums', locals: { albums: albums, user: @user }
    when 'pending-photos'
      return head :not_found unless is_own_profile
      photos = Photo.where(user_id: @user.id)
                    .joins(:photo_approvals)
                    .where(photo_approvals: { status: 'pending' })
                    .distinct
                    .includes(:photo_approvals, :riders, image_attachment: :blob)
      render partial: 'users/subtabs/pending_photos', locals: { photos: photos, user: @user }
    when 'hidden-photos'
      return head :not_found unless is_own_profile
      photos = @user.hidden_photos_from_profile.includes(:riders, image_attachment: :blob)
      render partial: 'users/subtabs/hidden_photos', locals: { photos: photos, user: @user }
    else
      head :not_found
    end
  end

  def following
    @user = User.find_by_friendly_or_id(params[:id])
    @query = params[:q].to_s.strip
    @users = @user.following
                 .includes(avatar_attachment: :blob)
                 .search_by_fields(@query, :username, :email, :name)
    @users = apply_user_filters(@users)
    @users = apply_user_sort(@users)
    @users = @users.page(params[:page])
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
                 .search_by_fields(@query, :username, :email, :name)
    @users = apply_user_filters(@users)
    @users = apply_user_sort(@users)
    @users = @users.page(params[:page])
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

  private

  def load_films_data
    # Optimized: removed :film_reviews from includes - using cached columns now
    @films = @user.all_films(viewing_user: current_user)
                  .includes(:riders, :filmers, :companies, thumbnail_attachment: :blob)

    # Apply film type filter if present
    @films = @films.where(film_type: params[:film_type]) if params[:film_type].present?

    # Apply search if query present
    @films = @films.where("LOWER(title) LIKE ?", "%#{@query.downcase}%") if @query.present?

    # Apply sorting
    @films = case params[:sort]
             when 'date_asc' then @films.reorder(release_date: :asc, created_at: :asc)
             when 'alpha_asc' then @films.reorder(Arel.sql("LOWER(title) ASC"))
             when 'alpha_desc' then @films.reorder(Arel.sql("LOWER(title) DESC"))
             else @films.reorder(release_date: :desc, created_at: :desc)
             end

    # Paginate
    @films = @films.page(params[:films_page]).per(18)
    @films_total_count = @films.total_count
    @films_has_more = @films.next_page.present?
  end

  def load_photos_data
    @photos = @user.all_photos(viewing_user: current_user)
                   .includes(:album, :riders, image_attachment: :blob)

    @photos = @photos.where("LOWER(title) LIKE ?", "%#{@query.downcase}%") if @query.present?

    @photos = @photos.page(params[:photos_page]).per(18)
    @photos_total_count = @photos.total_count
    @photos_has_more = @photos.next_page.present?
  end

  def apply_user_filters(scope)
    filtered = scope

    if params[:profile_type].present?
      profile_types = params[:profile_type].to_s.split(',').map(&:strip)
      filtered = filtered.where(profile_type: profile_types)
    end

    if params[:supporting].present? && user_signed_in?
      follower_id = current_user.id
      case params[:supporting]
      when 'supporting'
        filtered = filtered.joins(
          User.sanitize_sql_array([
            "INNER JOIN follows AS current_user_follows ON current_user_follows.followed_id = users.id AND current_user_follows.follower_id = ?",
            follower_id
          ])
        )
      when 'not_supporting'
        filtered = filtered.joins(
          User.sanitize_sql_array([
            "LEFT JOIN follows AS current_user_follows ON current_user_follows.followed_id = users.id AND current_user_follows.follower_id = ?",
            follower_id
          ])
        ).where("current_user_follows.id IS NULL")
      end
    end

    filtered
  end

  def apply_user_sort(scope)
    sort_key = params[:sort].presence || 'alpha_asc'

    case sort_key
    when 'alpha_desc'
      scope.order(Arel.sql("LOWER(COALESCE(NULLIF(users.name, ''), users.username)) DESC"))
    when 'followers_desc'
      scope.order(Arel.sql("users.followers_count DESC, LOWER(COALESCE(NULLIF(users.name, ''), users.username)) ASC"))
    else
      scope.order(Arel.sql("LOWER(COALESCE(NULLIF(users.name, ''), users.username)) ASC"))
    end
  end

  def fetch_user_cache(key, expires_in:)
    cache_key = CacheKeyHelpers.user_cache_key(@user, key)
    Rails.cache.fetch(cache_key, expires_in: expires_in) { yield }
  end
end
