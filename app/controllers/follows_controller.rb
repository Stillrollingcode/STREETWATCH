class FollowsController < ApplicationController
  before_action :authenticate_user!

  def create
    @user = User.find_by_friendly_or_id(params[:id])
    follow = current_user.follow(@user)

    # Create notification if user has notifications enabled
    if follow && @user.preference&.notify_on_new_follower
      Notification.create(
        user: @user,
        actor: current_user,
        notifiable: follow,
        action: 'followed'
      )
    end

    respond_to do |format|
      format.html { redirect_to redirect_path, notice: "You are now following #{@user.username}." }
      format.turbo_stream
    end
  end

  def destroy
    @user = User.find_by_friendly_or_id(params[:id])
    current_user.unfollow(@user)

    respond_to do |format|
      format.html { redirect_to redirect_path, notice: "You unfollowed #{@user.username}." }
      format.turbo_stream
    end
  end

  private

  def redirect_path
    referer_path = safe_referer_path
    return referer_path if referer_path.present? && referer_path == users_path

    user_path(@user)
  end

  def safe_referer_path
    return nil unless request.referer
    URI.parse(request.referer).path
  rescue URI::InvalidURIError
    nil
  end
end
