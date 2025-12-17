ActiveAdmin.register Film do
  permit_params :title, :description, :release_date, :custom_filmer_name, :custom_editor_name,
                :company, :company_user_id, :runtime, :music_featured, :film_type, :parent_film_title,
                :filmer_user_id, :editor_user_id, :custom_riders, :aspect_ratio, :youtube_url,
                :thumbnail, :video, rider_ids: []

  index do
    selectable_column
    id_column
    column :title
    column :film_type
    column :company
    column :release_date
    column "Filmer" do |film|
      film.filmer_display_name
    end
    column "Editor" do |film|
      film.editor_display_name
    end
    column :runtime
    column "Video" do |film|
      film.has_video? ? status_tag("yes", class: "ok") : status_tag("no")
    end
    column :created_at
    actions
  end

  filter :title
  filter :film_type, as: :select, collection: Film::FILM_TYPES
  filter :company
  filter :release_date
  filter :filmer_user, collection: -> { User.order(:username) }
  filter :editor_user, collection: -> { User.order(:username) }
  filter :created_at

  show do
    attributes_table do
      row :id
      row :title
      row :description
      row :film_type

      row "Company" do |film|
        if film.company_user
          link_to film.company_user.username, admin_user_path(film.company_user)
        elsif film.company.present?
          film.company
        else
          status_tag("empty", class: "warning")
        end
      end

      row :release_date
      row :runtime
      row :aspect_ratio
      row :parent_film_title

      row "Filmer" do |film|
        if film.filmer_user
          link_to film.filmer_user.username, admin_user_path(film.filmer_user)
        else
          film.custom_filmer_name
        end
      end

      row "Editor" do |film|
        if film.editor_user
          link_to film.editor_user.username, admin_user_path(film.editor_user)
        else
          film.custom_editor_name
        end
      end

      row "Riders" do |film|
        film.riders.map { |r| link_to r.username, admin_user_path(r) }.join(", ").html_safe
      end

      row :custom_riders

      row "YouTube URL" do |film|
        if film.youtube_url.present?
          link_to film.youtube_url, film.youtube_url, target: "_blank"
        end
      end

      row "Thumbnail" do |film|
        if film.thumbnail.attached?
          image_tag url_for(film.thumbnail), style: "max-width: 400px;"
        elsif film.youtube_thumbnail_url
          image_tag film.youtube_thumbnail_url, style: "max-width: 400px;"
        end
      end

      row "Video" do |film|
        if film.video.attached?
          link_to "Download Video", rails_blob_path(film.video, disposition: "attachment")
        end
      end

      row :music_featured
      row :created_at
      row :updated_at
    end

    panel "Stats" do
      attributes_table_for film do
        row "Favorites" do
          film.favorites.count
        end
        row "Comments" do
          film.comments.count
        end
        row "In Playlists" do
          film.playlists.count
        end
      end
    end

    panel "Approval Status" do
      if film.film_approvals.any?
        table_for film.film_approvals do
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
          column "Date" do |approval|
            if approval.status == 'pending'
              "Requested #{time_ago_in_words(approval.created_at)} ago"
            else
              "#{approval.status.titleize} #{time_ago_in_words(approval.updated_at)} ago"
            end
          end
        end
      else
        para "No profile approvals required for this film.", style: "color: #999; padding: 20px; text-align: center;"
      end

      if film.published?
        para "✓ This film is published and visible to the public.", style: "color: #6dd27f; padding: 20px; text-align: center; font-weight: bold;"
      else
        para "⏳ This film is pending approval and not yet visible to the public.", style: "color: #ff9800; padding: 20px; text-align: center; font-weight: bold;"
      end
    end
  end

  form do |f|
    f.inputs "Film Details" do
      f.input :title
      f.input :description, as: :text
      f.input :film_type, as: :select, collection: Film::FILM_TYPES
      f.input :company_user, as: :select, collection: User.where(profile_type: 'company').order(:username), include_blank: "Select a company profile or use custom name below"
      f.input :company, hint: "Only if company is not a registered user profile"
      f.input :release_date, as: :datepicker
      f.input :runtime, hint: "Runtime in minutes"
      f.input :aspect_ratio, hint: "e.g., 16:9, 4:3, 21:9"
      f.input :parent_film_title, hint: "For video parts or series"
    end

    f.inputs "Credits" do
      f.input :filmer_user, as: :select, collection: User.order(:username), include_blank: "Select a user or use custom name below"
      f.input :custom_filmer_name, hint: "Only if filmer is not a registered user"
      f.input :editor_user, as: :select, collection: User.order(:username), include_blank: "Select a user or use custom name below"
      f.input :custom_editor_name, hint: "Only if editor is not a registered user"
      f.input :riders, as: :check_boxes, collection: User.order(:username)
      f.input :custom_riders, as: :text, hint: "One rider name per line for non-registered riders"
    end

    f.inputs "Media" do
      f.input :youtube_url, hint: "YouTube video URL (if using YouTube hosting)"
      f.input :thumbnail, as: :file, hint: "Upload custom thumbnail image"
      f.input :video, as: :file, hint: "Upload video file (will be stored in S3)"
    end

    f.inputs "Additional Info" do
      f.input :music_featured, as: :text, hint: "Songs/artists featured in the film"
    end

    f.actions
  end
end
