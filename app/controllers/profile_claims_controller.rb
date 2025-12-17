class ProfileClaimsController < ApplicationController
  def new
    @user = User.find_by(claim_token: params[:token])

    if @user.nil? || !@user.admin_created? || @user.claimed_at.present?
      redirect_to root_path, alert: "Invalid or expired claim link."
    end
  end

  def create
    @user = User.find(params[:id])

    unless @user.admin_created? && @user.claimed_at.nil?
      redirect_to root_path, alert: "This profile cannot be claimed."
      return
    end

    # Send notification email to admin
    ProfileClaimMailer.claim_request(@user, params[:message]).deliver_later

    redirect_to root_path, notice: "Your claim request has been sent to the Streetwatch team. We'll be in touch soon!"
  end
end
