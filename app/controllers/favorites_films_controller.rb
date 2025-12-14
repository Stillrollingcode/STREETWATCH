class FavoritesFilmsController < ApplicationController
  before_action :authenticate_user!

  def index
    @films = current_user.favorited_films
                         .includes(thumbnail_attachment: :blob)
                         .recent
  end
end
