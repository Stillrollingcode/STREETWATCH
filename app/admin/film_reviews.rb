ActiveAdmin.register FilmReview do
  menu parent: "Films", priority: 3, label: "Reviews"

  permit_params :user_id, :film_id, :rating, :comment

  index do
    selectable_column
    id_column
    column "User" do |review|
      link_to review.user.username, admin_user_path(review.user)
    end
    column "Film" do |review|
      link_to review.film.title, admin_film_path(review.film)
    end
    column :rating do |review|
      span do
        "★" * review.rating + "☆" * (5 - review.rating)
      end
    end
    column :comment do |review|
      truncate(review.comment, length: 80) if review.comment.present?
    end
    column :created_at
    actions
  end

  filter :user, collection: -> { User.order(:username) }
  filter :film
  filter :rating, as: :select, collection: 1..5
  filter :comment
  filter :created_at

  show do
    attributes_table do
      row :id
      row "User" do |review|
        link_to review.user.username, admin_user_path(review.user)
      end
      row "Film" do |review|
        link_to review.film.title, admin_film_path(review.film)
      end
      row :rating do |review|
        span do
          "★" * review.rating + "☆" * (5 - review.rating) + " (#{review.rating}/5)"
        end
      end
      row :comment
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs "Review Details" do
      f.input :user, collection: User.order(:username)
      f.input :film
      f.input :rating, as: :select, collection: 1..5, include_blank: false
      f.input :comment, as: :text, input_html: { maxlength: 1000 }
    end

    f.actions
  end

  # Add batch actions for moderation
  batch_action :destroy, confirm: "Are you sure you want to delete these reviews?" do |ids|
    batch_action_collection.find(ids).each do |review|
      review.destroy
    end
    redirect_to collection_path, alert: "Reviews have been deleted."
  end
end
