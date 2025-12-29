class AddIsPublicToAlbums < ActiveRecord::Migration[8.0]
  def change
    add_column :albums, :is_public, :boolean, default: true, null: false
  end
end
