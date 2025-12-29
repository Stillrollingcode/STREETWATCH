class ProfileNotificationSettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_target_user

  def show
    @setting = current_user.notification_settings_for(@target_user)
  end

  def update
    @setting = current_user.notification_settings_for(@target_user)

    if @setting.update(notification_setting_params)
      respond_to do |format|
        format.html { redirect_to user_path(@target_user), notice: "Notification settings updated." }
        format.turbo_stream
      end
    else
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    @setting = current_user.profile_notification_settings.find_by(target_user: @target_user)
    @setting&.destroy

    respond_to do |format|
      format.html { redirect_to user_path(@target_user), notice: "Notification settings removed." }
      format.turbo_stream
    end
  end

  private

  def set_target_user
    @target_user = User.find_by_friendly_or_id(params[:user_id])
  end

  def notification_setting_params
    params.require(:profile_notification_setting).permit(
      :notify_on_films,
      :notify_on_photos,
      :notify_on_articles,
      :notify_on_featured_in_films,
      :notify_on_featured_in_photos,
      :notify_on_featured_in_articles,
      :muted
    )
  end
end
