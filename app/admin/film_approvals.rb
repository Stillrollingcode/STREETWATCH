ActiveAdmin.register FilmApproval do
  menu label: "Film Approvals"

  permit_params :status, :rejection_reason

  scope :all, default: true
  scope :pending
  scope :approved
  scope :rejected

  filter :film, as: :select, collection: -> { Film.order(:title) }
  filter :approver, as: :select, collection: -> { User.order(:username) }
  filter :approval_type, as: :select, collection: FilmApproval::APPROVAL_TYPES
  filter :status, as: :select, collection: FilmApproval::STATUSES
  filter :created_at

  index do
    selectable_column
    id_column
    column "Film" do |approval|
      link_to approval.film.title, admin_film_path(approval.film)
    end
    column "Approver" do |approval|
      link_to approval.approver.username, admin_user_path(approval.approver)
    end
    column "Role" do |approval|
      approval.approval_type.titleize
    end
    column "Status" do |approval|
      case approval.status
      when 'approved'
        status_tag("Approved", class: "ok")
      when 'rejected'
        status_tag("Rejected", class: "error")
      else
        status_tag("Pending", class: "warning")
      end
    end
    column "Created" do |approval|
      time_ago_in_words(approval.created_at) + " ago"
    end
    column "Updated" do |approval|
      if approval.status != 'pending'
        time_ago_in_words(approval.updated_at) + " ago"
      end
    end
    actions defaults: true do |approval|
      if approval.status == 'pending'
        link_to "Approve", approve_admin_film_approval_path(approval), method: :post, class: "member_link", style: "color: #6dd27f;"
      end
    end
  end

  show do
    attributes_table do
      row :id
      row "Film" do |approval|
        link_to approval.film.title, admin_film_path(approval.film)
      end
      row "Approver" do |approval|
        link_to approval.approver.username, admin_user_path(approval.approver)
      end
      row "Approval Type" do |approval|
        approval.approval_type.titleize
      end
      row "Status" do |approval|
        case approval.status
        when 'approved'
          status_tag("Approved", class: "ok")
        when 'rejected'
          status_tag("Rejected", class: "error")
        else
          status_tag("Pending", class: "warning")
        end
      end
      row :rejection_reason
      row :created_at
      row :updated_at
    end

    panel "Film Details" do
      attributes_table_for film_approval.film do
        row :title
        row :film_type
        row "Company" do |film|
          if film.company_user
            link_to film.company_user.username, admin_user_path(film.company_user)
          elsif film.company.present?
            film.company
          end
        end
        row :release_date
        row "Published" do |film|
          film.published? ? status_tag("Yes", class: "ok") : status_tag("No", class: "warning")
        end
      end
    end

    panel "Quick Actions" do
      if film_approval.status == 'pending'
        para do
          link_to "✓ Approve This Tag", approve_admin_film_approval_path(film_approval),
                  method: :post,
                  class: "button",
                  style: "background: #6dd27f; color: white; margin-right: 10px;",
                  data: { confirm: "Are you sure you want to approve this tag?" }
        end
        para do
          form_tag reject_admin_film_approval_path(film_approval), method: :post do
            text_area_tag :rejection_reason, nil, placeholder: "Reason for rejection (optional)",
                          style: "width: 100%; margin-bottom: 10px;"
            submit_tag "✗ Reject This Tag",
                       class: "button",
                       style: "background: #ff7b7b; color: white;",
                       data: { confirm: "Are you sure you want to reject this tag?" }
          end
        end
      else
        para "This approval has already been #{film_approval.status}.", style: "color: #999;"
      end
    end
  end

  form do |f|
    f.inputs "Approval Details" do
      f.input :film, as: :select, collection: Film.order(:title), input_html: { disabled: true }
      f.input :approver, as: :select, collection: User.order(:username), input_html: { disabled: true }
      f.input :approval_type, input_html: { disabled: true }
      f.input :status, as: :select, collection: FilmApproval::STATUSES
      f.input :rejection_reason, as: :text, hint: "Only required if rejecting"
    end
    f.actions
  end

  member_action :approve, method: :post do
    resource.approve!
    redirect_to admin_film_approval_path(resource), notice: "Approval granted! Film will be published when all approvals are complete."
  end

  member_action :reject, method: :post do
    reason = params[:rejection_reason].presence || "No reason provided"
    resource.reject!(reason)
    redirect_to admin_film_approval_path(resource), notice: "Tag rejected."
  end

  batch_action :approve do |ids|
    FilmApproval.where(id: ids, status: 'pending').find_each(&:approve!)
    redirect_to collection_path, notice: "#{ids.count} approvals granted."
  end

  batch_action :reject do |ids|
    FilmApproval.where(id: ids, status: 'pending').find_each { |a| a.reject!("Batch rejected by admin") }
    redirect_to collection_path, notice: "#{ids.count} approvals rejected."
  end
end
