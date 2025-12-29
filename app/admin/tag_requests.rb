ActiveAdmin.register TagRequest do
  permit_params :film_id, :requester_id, :role, :status, :message

  index do
    selectable_column
    id_column
    column :film do |tag_request|
      link_to tag_request.film.title, admin_film_path(tag_request.film)
    end
    column :requester do |tag_request|
      link_to tag_request.requester.username, admin_user_path(tag_request.requester)
    end
    column :role
    column :status
    column :created_at
    actions
  end

  filter :film
  filter :requester, as: :select, collection: -> { User.order(:username) }
  filter :role, as: :select, collection: TagRequest::ROLES
  filter :status, as: :select, collection: TagRequest::STATUSES
  filter :created_at

  show do
    attributes_table do
      row :id
      row :film do |tag_request|
        link_to tag_request.film.title, admin_film_path(tag_request.film)
      end
      row :requester do |tag_request|
        link_to tag_request.requester.username, admin_user_path(tag_request.requester)
      end
      row :role
      row :status
      row :message
      row :created_at
      row :updated_at
    end

    panel "Actions" do
      if tag_request.pending?
        div do
          button_to "Approve Request", approve_tag_request_path(tag_request), method: :post, class: "button"
        end
        div do
          button_to "Deny Request", deny_tag_request_path(tag_request), method: :post, class: "button"
        end
      else
        div do
          "This request has already been #{tag_request.status}."
        end
      end
    end
  end

  form do |f|
    f.inputs "Tag Request Details" do
      f.input :film, as: :select, collection: Film.order(:title).pluck(:title, :id)
      f.input :requester, as: :select, collection: User.order(:username).pluck(:username, :id)
      f.input :role, as: :select, collection: TagRequest::ROLES
      f.input :status, as: :select, collection: TagRequest::STATUSES
      f.input :message
    end
    f.actions
  end
end
