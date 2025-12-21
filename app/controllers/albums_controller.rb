class AlbumsController < ApplicationController
  before_action :set_album, only: [:show, :edit, :update, :destroy]
  before_action :authenticate_user!, except: [:index, :show]

  def index
    @albums = Album.includes(:user, photos: :image_attachment)

    # Search
    if params[:search].present?
      @albums = @albums.where('title LIKE ? OR description LIKE ?',
                              "%#{params[:search]}%", "%#{params[:search]}%")
    end

    # Sort
    @albums = case params[:sort]
    when 'oldest' then @albums.order(created_at: :asc)
    when 'alphabetical' then @albums.order(title: :asc)
    when 'by_date' then @albums.by_date
    else @albums.recent
    end

    @albums = @albums.page(params[:page]).per(20) if defined?(Kaminari)
  end

  def show
    @photos = @album.photos.includes(:user, :photographer_user, :riders, image_attachment: :blob)
                           .order(created_at: :desc)
  end

  def new
    @album = current_user.albums.build
  end

  def create
    @album = current_user.albums.build(album_params)
    if @album.save
      redirect_to @album, notice: 'Album created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize_album!
  end

  def update
    authorize_album!
    if @album.update(album_params)
      redirect_to @album, notice: 'Album updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize_album!
    @album.destroy
    redirect_to albums_path, notice: 'Album deleted successfully.'
  end

  private

  def set_album
    @album = Album.find_by_friendly_or_id(params[:id])
    redirect_to albums_path, alert: 'Album not found' unless @album
  end

  def album_params
    params.require(:album).permit(:title, :description, :date)
  end

  def authorize_album!
    return if @album.user == current_user

    redirect_to albums_path, alert: 'Not authorized'
  end
end
