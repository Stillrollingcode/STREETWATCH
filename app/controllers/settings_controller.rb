class SettingsController < ApplicationController
  before_action :authenticate_user!

  def show
    @preference = current_user.preference || current_user.build_preference
  end

  def update
    @preference = current_user.preference || current_user.build_preference

    if @preference.update(preference_params)
      redirect_to settings_path, notice: "Settings saved successfully!"
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def preference_params
    params.require(:user_preference).permit(:theme, :accent_hue)
  end
end
