ActiveAdmin.register PhotoApproval do
  menu parent: "Content", priority: 4, label: "Photo Approvals"

  permit_params :photo_id, :approver_id, :approval_type, :status, :rejection_reason

  index do
    selectable_column
    id_column
    column :photo do |approval|
      link_to truncate(approval.photo.title, length: 40), admin_photo_path(approval.photo)
    end
    column :approver
    column :approval_type do |approval|
      status_tag approval.approval_type
    end
    column :status do |approval|
      status_tag approval.status, class: approval.status
    end
    column :created_at
    actions
  end

  filter :photo
  filter :approver
  filter :approval_type, as: :select, collection: %w[photographer rider company]
  filter :status, as: :select, collection: %w[pending approved rejected]
  filter :created_at

  show do
    attributes_table do
      row :id
      row :photo do |approval|
        link_to approval.photo.title, admin_photo_path(approval.photo)
      end
      row "Photo Preview" do |approval|
        if approval.photo.image.attached?
          image_tag url_for(approval.photo.image.variant(resize_to_limit: [300, 300])), style: 'border-radius: 8px;'
        end
      end
      row :approver
      row :approval_type do |approval|
        status_tag approval.approval_type
      end
      row :status do |approval|
        status_tag approval.status, class: approval.status
      end
      row :rejection_reason
      row :created_at
      row :updated_at
    end

    panel "Quick Actions" do
      if photo_approval.status == 'pending'
        div do
          button_to 'Approve', approve_photo_approval_path(photo_approval), method: :patch, class: 'button', style: 'background-color: #4CAF50; color: white; padding: 8px 16px; border-radius: 4px; margin-right: 8px;'
        end
        div do
          button_to 'Reject', reject_photo_approval_path(photo_approval), method: :patch, class: 'button', style: 'background-color: #f44336; color: white; padding: 8px 16px; border-radius: 4px;'
        end
      end
    end
  end

  form do |f|
    f.inputs "Photo Approval Details" do
      f.input :photo, as: :select, collection: Photo.order(created_at: :desc).limit(100).map { |p| [p.title, p.id] }
      f.input :approver, as: :select, collection: User.order(:name)
      f.input :approval_type, as: :select, collection: %w[photographer rider company]
      f.input :status, as: :select, collection: %w[pending approved rejected]
      f.input :rejection_reason, hint: "Only required if status is rejected"
    end
    f.actions
  end
end
