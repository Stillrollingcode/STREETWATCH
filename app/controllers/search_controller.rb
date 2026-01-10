class SearchController < ApplicationController
  respond_to :json

  def index
    query = params[:q].to_s.strip

    if query.blank?
      return respond_to do |format|
        format.json { render json: { films: [], photos: [], users: [], albums: [] } }
        format.html { redirect_to root_path }
      end
    end

    # Determine database type once
    is_pg = postgresql?

    # Determine limit based on format (more results for HTML page)
    limit_films = request.format.html? ? 50 : 8
    limit_photos = request.format.html? ? 50 : 8
    limit_users = request.format.html? ? 50 : 8
    limit_albums = request.format.html? ? 50 : 6

    # Search Films - title, company, description, friendly_id, and tagged users
    @films = Film.where(
                  is_pg ?
                    "films.title ILIKE :q OR
                     films.friendly_id ILIKE :q OR
                     COALESCE(films.company, '') ILIKE :q OR
                     COALESCE(films.description, '') ILIKE :q OR
                     COALESCE(films.custom_filmer_name, '') ILIKE :q OR
                     COALESCE(films.custom_editor_name, '') ILIKE :q OR
                     COALESCE(films.custom_riders, '') ILIKE :q"
                  :
                    "LOWER(films.title) LIKE :q OR
                     LOWER(films.friendly_id) LIKE :q OR
                     LOWER(COALESCE(films.company, '')) LIKE :q OR
                     LOWER(COALESCE(films.description, '')) LIKE :q OR
                     LOWER(COALESCE(films.custom_filmer_name, '')) LIKE :q OR
                     LOWER(COALESCE(films.custom_editor_name, '')) LIKE :q OR
                     LOWER(COALESCE(films.custom_riders, '')) LIKE :q",
                  q: is_pg ? "%#{query}%" : "%#{query.downcase}%"
                )
                .distinct
                .limit(limit_films)

    # Search Photos - title, description, friendly_id, and tagged users
    @photos = Photo.where(
                    is_pg ?
                      "photos.title ILIKE :q OR
                       photos.friendly_id ILIKE :q OR
                       COALESCE(photos.description, '') ILIKE :q OR
                       COALESCE(photos.custom_photographer_name, '') ILIKE :q OR
                       COALESCE(photos.custom_riders, '') ILIKE :q"
                    :
                      "LOWER(photos.title) LIKE :q OR
                       LOWER(photos.friendly_id) LIKE :q OR
                       LOWER(COALESCE(photos.description, '')) LIKE :q OR
                       LOWER(COALESCE(photos.custom_photographer_name, '')) LIKE :q OR
                       LOWER(COALESCE(photos.custom_riders, '')) LIKE :q",
                    q: is_pg ? "%#{query}%" : "%#{query.downcase}%"
                  )
                  .distinct
                  .limit(limit_photos)

    # Search Users - username, email, name, bio
    @users = User.where(
                  is_pg ?
                    "users.username ILIKE :q OR
                     COALESCE(users.email, '') ILIKE :q OR
                     COALESCE(users.name, '') ILIKE :q OR
                     COALESCE(users.bio, '') ILIKE :q"
                  :
                    "LOWER(users.username) LIKE :q OR
                     LOWER(COALESCE(users.email, '')) LIKE :q OR
                     LOWER(COALESCE(users.name, '')) LIKE :q OR
                     LOWER(COALESCE(users.bio, '')) LIKE :q",
                  q: is_pg ? "%#{query}%" : "%#{query.downcase}%"
                )
                .limit(limit_users)

    # Search Albums - title, description
    @albums = Album.where(
                    is_pg ?
                      "albums.title ILIKE :q OR
                       albums.friendly_id ILIKE :q OR
                       COALESCE(albums.description, '') ILIKE :q"
                    :
                      "LOWER(albums.title) LIKE :q OR
                       LOWER(albums.friendly_id) LIKE :q OR
                       LOWER(COALESCE(albums.description, '')) LIKE :q",
                    q: is_pg ? "%#{query}%" : "%#{query.downcase}%"
                  )
                  .distinct
                  .limit(limit_albums)

    respond_to do |format|
      format.json {
        payload = {
          films: @films.map { |f| {
            id: f.friendly_id || f.id,
            title: f.title,
            company: f.company,
            film_type: f.formatted_film_type,
            type: 'film'
          }},
          photos: @photos.map { |p| {
            id: p.friendly_id || p.id,
            title: p.title,
            type: 'photo'
          }},
          users: @users.map { |u| {
            id: u.id,
            username: u.username,
            name: u.name,
            profile_type: u.profile_type,
            type: 'user'
          }},
          albums: @albums.map { |a| {
            id: a.friendly_id || a.id,
            title: a.title,
            type: 'album'
          }}
        }
        render json: payload
      }
      format.html # renders views/search/index.html.erb
    end
  end

  private

  def postgresql?
    ActiveRecord::Base.connection.adapter_name.downcase == 'postgresql'
  end
end
