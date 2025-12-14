class FavoritesController < ApplicationController
  before_action :authenticate_user!

  def create
    @film = Film.find(params[:film_id])
    @favorite = current_user.favorites.build(film: @film)

    if @favorite.save
      respond_to do |format|
        format.html { redirect_to @film, notice: "Added to favorites" }
        format.turbo_stream
      end
    else
      redirect_to @film, alert: "Could not add to favorites"
    end
  end

  def destroy
    @favorite = current_user.favorites.find(params[:id])
    @film = @favorite.film
    @favorite.destroy

    respond_to do |format|
      format.html { redirect_to @film, notice: "Removed from favorites" }
      format.turbo_stream
    end
  end
end
