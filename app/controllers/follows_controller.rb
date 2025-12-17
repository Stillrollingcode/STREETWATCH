class FollowsController < ApplicationController
  before_action :authenticate_user!

  def create
    @user = User.find(params[:id])
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
    @user = User.find(params[:id])
    current_user.unfollow(@user)

    respond_to do |format|
      format.html { redirect_to redirect_path, notice: "You unfollowed #{@user.username}." }
      format.turbo_stream
    end
  end

  private

  def redirect_path
    # If coming from users index, redirect back there
    if request.referer&.include?('/users')
      users_path
    else
      user_path(@user)
    end
  end
end
