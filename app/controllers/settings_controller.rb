class SettingsController < ApplicationController
  before_action :authenticate_user!

  def show
    @preference = current_user.preference || current_user.build_preference
  end

  def update
    @preference = current_user.preference || current_user.build_preference

    if @preference.update(preference_params)
      # Force full page reload to refresh theme CSS variables in head
      redirect_to settings_path, notice: "Settings saved successfully!", allow_other_host: false
      response.headers['Turbo-Visit-Control'] = 'reload'
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def preference_params
    params.require(:user_preference).permit(
      :theme,
      :accent_hue,
      :email_notifications_enabled,
      :notify_on_new_follower,
      :notify_on_comment,
      :notify_on_reply,
      :notify_on_mention,
      :notify_on_favorite
    )
  end
end
