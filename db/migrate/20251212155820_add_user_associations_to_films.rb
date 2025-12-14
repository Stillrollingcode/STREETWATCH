class AddUserAssociationsToFilms < ActiveRecord::Migration[8.0]
  def change
    # Add foreign keys for filmer and editor users
    add_reference :films, :filmer_user, foreign_key: { to_table: :users }, null: true
    add_reference :films, :editor_user, foreign_key: { to_table: :users }, null: true

    # Rename existing filmer/editor columns to custom names
    rename_column :films, :filmer, :custom_filmer_name
    rename_column :films, :editor, :custom_editor_name

    # Add custom riders field for non-profile riders
    add_column :films, :custom_riders, :text
  end
end
