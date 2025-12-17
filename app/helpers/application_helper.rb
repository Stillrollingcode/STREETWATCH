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
        crumbs << { name: "Films", path: films_path }
        crumbs << { name: @film.title, path: nil }
      elsif action_name == "new"
        crumbs << { name: "Films", path: films_path }
        crumbs << { name: "New Film", path: nil }
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
end
