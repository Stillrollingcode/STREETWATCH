module ApplicationHelper
  def breadcrumbs
    crumbs = []

    # Always start with Home
    crumbs << { name: "Home", path: root_path }

    # Determine current page breadcrumbs based on controller and action
    case controller_name
    when "films"
      if action_name == "index"
        crumbs << { name: "Films", path: nil }
      elsif action_name == "show" && @film
        # Check if we came from a user profile by looking at the referer
        if request.referer&.include?('/users/') && (match = request.referer.match(/\/users\/([^\/\?#]+)/))
          # Extract user ID from referer and create breadcrumb
          if (user = User.find_by_friendly_or_id(match[1]))
            crumbs << { name: user.username, path: user_path(user) }
          else
            crumbs << { name: "Films", path: films_path }
          end
        else
          crumbs << { name: "Films", path: films_path }
        end
        crumbs << { name: @film.title, path: nil }
      elsif action_name == "new"
        crumbs << { name: "Films", path: films_path }
        crumbs << { name: "New Film", path: nil }
      end
    when "photos"
      if action_name == "index"
        crumbs << { name: "Photos", path: nil }
      elsif action_name == "show" && @photo
        # Check if we came from a user profile by looking at the referer
        if request.referer&.include?('/users/') && (match = request.referer.match(/\/users\/([^\/\?#]+)/))
          # Extract user ID from referer and create breadcrumb
          if (user = User.find_by_friendly_or_id(match[1]))
            crumbs << { name: user.username, path: user_path(user) }
          else
            crumbs << { name: "Photos", path: photos_path }
          end
        else
          crumbs << { name: "Photos", path: photos_path }
        end
        crumbs << { name: @photo.title, path: nil }
      elsif action_name == "new"
        crumbs << { name: "Photos", path: photos_path }
        crumbs << { name: "New Photo", path: nil }
      end
    when "users"
      if action_name == "show" && @user
        crumbs << { name: @user.username, path: nil }
      elsif action_name == "index"
        crumbs << { name: "Users", path: nil }
      elsif action_name == "following" && @user
        crumbs << { name: @user.username, path: user_path(@user) }
        crumbs << { name: "Following", path: nil }
      elsif action_name == "followers" && @user
        crumbs << { name: @user.username, path: user_path(@user) }
        crumbs << { name: "Followers", path: nil }
      end
    when "registrations"
      if action_name == "edit"
        crumbs << { name: current_user.username, path: user_path(current_user) }
        crumbs << { name: "Settings", path: nil }
      end
    when "playlists"
      if action_name == "index"
        crumbs << { name: "Playlists", path: nil }
      elsif action_name == "show" && @playlist
        crumbs << { name: "Playlists", path: playlists_path }
        crumbs << { name: @playlist.name, path: nil }
      end
    when "notifications"
      crumbs << { name: "Notifications", path: nil }
    when "profile_notification_settings"
      if @user
        crumbs << { name: @user.username, path: user_path(@user) }
        crumbs << { name: "Notification Settings", path: nil }
      end
    when "settings"
      crumbs << { name: "Settings", path: nil }
    end

    crumbs
  end

  def can_delete_comment?(user, film, comment)
    # Allow comment deletion if user is the film uploader, filmer, or editor
    return false unless user && film && comment
    film.user == user || film.filmer_user == user || film.editor_user == user
  end

  def group_notifications(notifications)
    grouped = {}

    notifications.each do |notification|
      # Only group favorited and commented actions
      if ['favorited', 'commented'].include?(notification.action)
        # Create a unique key based on action + notifiable (film/photo)
        key = "#{notification.action}_#{notification.notifiable_type}_#{notification.notifiable_id}"

        grouped[key] ||= {
          action: notification.action,
          notifiable: notification.notifiable,
          notifiable_type: notification.notifiable_type,
          notifications: [],
          latest_created_at: notification.created_at
        }

        grouped[key][:notifications] << notification
        # Keep track of the latest notification time
        if notification.created_at > grouped[key][:latest_created_at]
          grouped[key][:latest_created_at] = notification.created_at
        end
      else
        # Non-groupable notifications get their own key
        key = "single_#{notification.id}"
        grouped[key] = {
          action: notification.action,
          notifiable: notification.notifiable,
          notifiable_type: notification.notifiable_type,
          notifications: [notification],
          latest_created_at: notification.created_at
        }
      end
    end

    # Sort by latest_created_at and return array of groups
    grouped.values.sort_by { |g| g[:latest_created_at] }.reverse
  end
end
