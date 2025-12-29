# frozen_string_literal: true
ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    columns do
      column do
        panel "Pending Film Approvals" do
          table_for FilmApproval.pending.includes(:film, :approver).limit(10) do
            column "Film" do |approval|
              link_to approval.film.title, admin_film_path(approval.film)
            end
            column "Approver" do |approval|
              link_to approval.approver.username, admin_user_path(approval.approver)
            end
            column "Role" do |approval|
              approval.approval_type.titleize
            end
            column "Submitted" do |approval|
              time_ago_in_words(approval.created_at) + " ago"
            end
          end
          if FilmApproval.pending.empty?
            para "No pending approvals", style: "text-align: center; color: #999; padding: 20px;"
          end
        end
      end

      column do
        panel "Recent Films" do
          table_for Film.includes(:pending_approvals).order(created_at: :desc).limit(5) do
            column "Title" do |film|
              link_to film.title, admin_film_path(film)
            end
            column "Status" do |film|
              if film.published?
                status_tag "Published", class: "ok"
              else
                status_tag "Pending Approval", class: "warning"
              end
            end
            column "Created" do |film|
              time_ago_in_words(film.created_at) + " ago"
            end
          end
        end

        panel "Recent Users" do
          table_for User.order(created_at: :desc).limit(5) do
            column "Username" do |user|
              link_to user.username, admin_user_path(user)
            end
            column "Type" do |user|
              user.profile_type.titleize
            end
            column "Created" do |user|
              time_ago_in_words(user.created_at) + " ago"
            end
          end
        end
      end
    end
  end # content
end
