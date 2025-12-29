ActiveAdmin.register PhotoApproval do
  menu parent: "Photos", priority: 3, label: "Approvals"

  permit_params :photo_id, :approver_id, :approval_type, :status, :rejection_reason

  scope :all, default: true
  scope :pending
  scope :approved
  scope :rejected

  index do
    selectable_column
    column "ID", :friendly_id
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

  controller do
    def find_resource
      PhotoApproval.find_by_friendly_or_id(params[:id])
    end
  end

  show do
    attributes_table do
      row :friendly_id
      row "Database ID", :id
      row :photo do |approval|
        link_to approval.photo.title, admin_photo_path(approval.photo)
      end
      row "Photo Preview" do |approval|
        if approval.photo.image.attached?
          image_tag url_for(approval.photo.image), style: 'max-width: 300px; border-radius: 8px;'
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
      case photo_approval.status
      when 'pending'
        div do
          button_to 'Approve', approve_admin_photo_approval_path(photo_approval), method: :patch, class: 'button', style: 'background-color: #4CAF50; color: white; padding: 8px 16px; border-radius: 4px; margin-right: 8px;'
        end
        div do
          button_to 'Reject', reject_admin_photo_approval_path(photo_approval), method: :patch, class: 'button', style: 'background-color: #f44336; color: white; padding: 8px 16px; border-radius: 4px;'
        end
      when 'approved'
        para "This approval was granted.", style: "color: #4CAF50; font-weight: bold;"
        div do
          button_to 'Change to Rejected', reject_admin_photo_approval_path(photo_approval), method: :patch, class: 'button', style: 'background-color: #f44336; color: white; padding: 8px 16px; border-radius: 4px;', data: { confirm: 'Change this approval to rejected?' }
        end
        div do
          button_to 'Reset to Pending', reset_admin_photo_approval_path(photo_approval), method: :patch, class: 'button', style: 'background-color: #ff9800; color: white; padding: 8px 16px; border-radius: 4px; margin-top: 8px;', data: { confirm: 'Reset this approval to pending?' }
        end
      when 'rejected'
        para "This approval was rejected: #{photo_approval.rejection_reason}", style: "color: #f44336; font-weight: bold;"
        div do
          button_to 'Change to Approved', approve_admin_photo_approval_path(photo_approval), method: :patch, class: 'button', style: 'background-color: #4CAF50; color: white; padding: 8px 16px; border-radius: 4px;', data: { confirm: 'Change this approval to approved?' }
        end
        div do
          button_to 'Reset to Pending', reset_admin_photo_approval_path(photo_approval), method: :patch, class: 'button', style: 'background-color: #ff9800; color: white; padding: 8px 16px; border-radius: 4px; margin-top: 8px;', data: { confirm: 'Reset this approval to pending?' }
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

  member_action :approve, method: :patch do
    resource.update!(status: 'approved', rejection_reason: nil)
    redirect_to admin_photo_approval_path(resource), notice: "Photo approval granted!"
  end

  member_action :reject, method: :patch do
    reason = params[:rejection_reason].presence || "No reason provided"
    resource.update!(status: 'rejected', rejection_reason: reason)
    redirect_to admin_photo_approval_path(resource), notice: "Photo approval rejected."
  end

  member_action :reset, method: :patch do
    resource.update!(status: 'pending', rejection_reason: nil)
    redirect_to admin_photo_approval_path(resource), notice: "Photo approval reset to pending."
  end

  batch_action :approve do |ids|
    count = PhotoApproval.where(id: ids).update_all(status: 'approved', rejection_reason: nil)
    redirect_to collection_path, notice: "#{count} photo approval(s) changed to approved."
  end

  batch_action :reject do |ids|
    count = PhotoApproval.where(id: ids).update_all(status: 'rejected', rejection_reason: 'Batch rejected by admin')
    redirect_to collection_path, notice: "#{count} photo approval(s) changed to rejected."
  end

  batch_action :reset_to_pending, label: "Reset to Pending" do |ids|
    count = PhotoApproval.where(id: ids).update_all(status: 'pending', rejection_reason: nil)
    redirect_to collection_path, notice: "#{count} photo approval(s) reset to pending."
  end
end
