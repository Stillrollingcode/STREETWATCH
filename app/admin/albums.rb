ActiveAdmin.register Album do
  menu parent: "Photos", priority: 4

  permit_params :title, :description, :date, :user_id

  index do
    selectable_column
    column "ID", :friendly_id
    column :title
    column :user
    column "Photos" do |album|
      album.photos.count
    end
    column :date
    column :created_at
    actions
  end

  filter :title
  filter :user
  filter :date
  filter :created_at

  controller do
    def find_resource
      Album.find_by_friendly_or_id(params[:id])
    end
  end

  show do
    attributes_table do
      row :friendly_id
      row "Database ID", :id
      row :title
      row :description
      row :date
      row :user
      row :photos_count do |album|
        album.photos.count
      end
      row :created_at
      row :updated_at
    end

    panel "Photos in Album" do
      table_for album.photos.order(created_at: :desc) do
        column "Thumbnail" do |photo|
          if photo.image.attached?
            image_tag url_for(photo.image.variant(resize_to_limit: [100, 100])), style: 'max-width: 100px; border-radius: 4px;'
          end
        end
        column :title do |photo|
          link_to photo.title, admin_photo_path(photo)
        end
        column :photographer_name
        column :created_at
      end
    end
  end

  form do |f|
    f.inputs "Album Details" do
      f.input :title
      f.input :description
      f.input :date
      f.input :user, as: :select, collection: User.order(:name)
    end
    f.actions
  end
end
