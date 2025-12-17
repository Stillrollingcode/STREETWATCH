class AddFriendlyIds < ActiveRecord::Migration[8.0]
  def change
    # Films: F####
    add_column :films, :friendly_id, :string
    add_index :films, :friendly_id, unique: true

    # Users: U####
    add_column :users, :friendly_id, :string
    add_index :users, :friendly_id, unique: true

    # Comments: C####
    add_column :comments, :friendly_id, :string
    add_index :comments, :friendly_id, unique: true

    # Film Approvals: FA####
    add_column :film_approvals, :friendly_id, :string
    add_index :film_approvals, :friendly_id, unique: true

    # Playlists: PL#### (using PL to avoid conflict with photos)
    add_column :playlists, :friendly_id, :string
    add_index :playlists, :friendly_id, unique: true
  end
end
