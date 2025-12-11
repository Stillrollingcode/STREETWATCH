class UsernamesController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :show

  def show
    username = params[:username].to_s.strip.downcase
    available = username.present? && !User.exists?(username: username)
    render json: { available: available, username: username, message: available ? "Available" : "Taken" }
  end
end
