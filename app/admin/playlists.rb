ActiveAdmin.register Playlist do
  menu parent: "Films", priority: 4

  permit_params :user_id, :name, :description

  index do
    selectable_column
    id_column
    column :name
    column "User" do |playlist|
      link_to playlist.user.username, admin_user_path(playlist.user)
    end
    column "Films" do |playlist|
      playlist.films.count
    end
    column :created_at
    actions
  end

  filter :name
  filter :user, collection: -> { User.order(:username) }
  filter :created_at

  show do
    attributes_table do
      row :id
      row :name
      row :description
      row "User" do |playlist|
        link_to playlist.user.username, admin_user_path(playlist.user)
      end
      row :created_at
      row :updated_at
    end

    panel "Films in Playlist" do
      table_for playlist.playlist_films.order(:position) do
        column "Position" do |pf|
          pf.position
        end
        column "Film" do |pf|
          link_to pf.film.title, admin_film_path(pf.film)
        end
        column "Film Type" do |pf|
          pf.film.film_type
        end
        column "Added At" do |pf|
          pf.created_at
        end
      end
    end
  end

  form do |f|
    f.inputs "Playlist Details" do
      f.input :user, collection: User.order(:username)
      f.input :name
      f.input :description, as: :text
    end

    f.actions
  end
end
