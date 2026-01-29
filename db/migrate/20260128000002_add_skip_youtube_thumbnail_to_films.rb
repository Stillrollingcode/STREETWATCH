class AddSkipYoutubeThumbnailToFilms < ActiveRecord::Migration[8.0]
  def change
    add_column :films, :skip_youtube_thumbnail, :boolean, default: false
  end
end
