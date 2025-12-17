class PlaylistsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_playlist, only: [:show, :edit, :update, :destroy, :add_film, :remove_film]

  def index
    @playlists = current_user.playlists.recent
  end

  def show
    @films = @playlist.playlist_films.ordered.includes(film: { thumbnail_attachment: :blob }).map(&:film)
  end

  def new
    @playlist = current_user.playlists.build
  end

  def create
    @playlist = current_user.playlists.build(playlist_params)

    if @playlist.save
      # Auto-add film if film_id is provided
      if params[:film_id].present?
        film = Film.find_by_friendly_or_id(params[:film_id])
        @playlist.playlist_films.create(film: film, position: 1)
        redirect_to film, notice: "Playlist created and film added!"
      else
        redirect_to @playlist, notice: "Playlist created"
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @playlist.update(playlist_params)
      redirect_to @playlist, notice: "Playlist updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @playlist.destroy
    redirect_to playlists_path, notice: "Playlist deleted"
  end

  def add_film
    film = Film.find_by_friendly_or_id(params[:film_id])
    position = @playlist.playlist_films.maximum(:position).to_i + 1

    @playlist_film = @playlist.playlist_films.build(film: film, position: position)

    if @playlist_film.save
      redirect_to film, notice: "Added to #{@playlist.name}"
    else
      redirect_to film, alert: "Could not add to playlist"
    end
  end

  def remove_film
    @playlist_film = @playlist.playlist_films.find_by(film_id: params[:film_id])
    @playlist_film&.destroy

    redirect_to @playlist, notice: "Removed from playlist"
  end

  private

  def set_playlist
    @playlist = Playlist.find_by_friendly_or_id(params[:id])
    # Ensure it belongs to current user
    redirect_to playlists_path, alert: "Playlist not found" unless @playlist&.user == current_user
  end

  def playlist_params
    params.require(:playlist).permit(:name, :description)
  end
end
