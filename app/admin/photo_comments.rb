ActiveAdmin.register PhotoComment do
  menu parent: "Content", priority: 5, label: "Photo Comments"

  permit_params :user_id, :photo_id, :body, :parent_id

  index do
    selectable_column
    id_column
    column :user
    column :photo do |comment|
      link_to truncate(comment.photo.title, length: 40), admin_photo_path(comment.photo)
    end
    column :body do |comment|
      truncate(comment.body, length: 80)
    end
    column "Reply?" do |comment|
      comment.parent_id ? "Yes" : "No"
    end
    column :created_at
    actions
  end

  filter :user
  filter :photo
  filter :created_at

  show do
    attributes_table do
      row :id
      row :user
      row :photo do |comment|
        link_to comment.photo.title, admin_photo_path(comment.photo)
      end
      row "Photo Preview" do |comment|
        if comment.photo.image.attached?
          image_tag url_for(comment.photo.image.variant(resize_to_limit: [200, 200])), style: 'border-radius: 8px;'
        end
      end
      row :body
      row "Parent Comment" do |comment|
        if comment.parent
          link_to truncate(comment.parent.body, length: 50), admin_photo_comment_path(comment.parent)
        else
          "None (Top-level comment)"
        end
      end
      row :created_at
      row :updated_at
    end

    panel "Replies to This Comment" do
      table_for photo_comment.replies.order(created_at: :asc) do
        column :user
        column :body do |reply|
          truncate(reply.body, length: 100)
        end
        column :created_at
        column "Actions" do |reply|
          link_to "View", admin_photo_comment_path(reply)
        end
      end
    end
  end

  form do |f|
    f.inputs "Photo Comment Details" do
      f.input :user, as: :select, collection: User.order(:name)
      f.input :photo, as: :select, collection: Photo.order(created_at: :desc).limit(100).map { |p| [p.title, p.id] }
      f.input :body, as: :text
      f.input :parent, as: :select, collection: PhotoComment.where(parent_id: nil).order(created_at: :desc).limit(50).map { |c| [truncate(c.body, length: 50), c.id] }, include_blank: "None (top-level comment)"
    end
    f.actions
  end
end
