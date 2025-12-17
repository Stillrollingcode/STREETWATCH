ActiveAdmin.register Comment, as: "FilmComment" do
  permit_params :user_id, :film_id, :body, :parent_id

  index do
    selectable_column
    id_column
    column "User" do |comment|
      link_to comment.user.username, admin_user_path(comment.user)
    end
    column "Film" do |comment|
      link_to comment.film.title, admin_film_path(comment.film)
    end
    column :body do |comment|
      truncate(comment.body, length: 80)
    end
    column "Reply to" do |comment|
      if comment.parent_id
        link_to "Comment ##{comment.parent_id}", admin_film_comment_path(comment.parent_id)
      end
    end
    column :created_at
    actions
  end

  filter :user, collection: -> { User.order(:username) }
  filter :film
  filter :body
  filter :created_at

  show do
    attributes_table do
      row :id
      row "User" do |comment|
        link_to comment.user.username, admin_user_path(comment.user)
      end
      row "Film" do |comment|
        link_to comment.film.title, admin_film_path(comment.film)
      end
      row :body
      row "Parent Comment" do |comment|
        if comment.parent_id
          link_to "Comment ##{comment.parent_id}", admin_film_comment_path(comment.parent_id)
        end
      end
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs "Comment Details" do
      f.input :user, collection: User.order(:username)
      f.input :film
      f.input :body, as: :text
      f.input :parent_id, as: :number, hint: "ID of parent comment if this is a reply"
    end

    f.actions
  end
end
