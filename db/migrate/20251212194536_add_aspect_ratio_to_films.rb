class AddAspectRatioToFilms < ActiveRecord::Migration[8.0]
  def change
    add_column :films, :aspect_ratio, :string, default: '16:9'
  end
end
