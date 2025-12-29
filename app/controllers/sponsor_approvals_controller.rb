class SponsorApprovalsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_approval, only: [:approve, :reject]
  before_action :verify_sponsor, only: [:approve, :reject]
  before_action :set_approval_with_verify, only: [:reset]

  def index
    @pending_approvals = current_user.sponsored_by_approvals.pending.includes(user: [:avatar_attachment])
    @approved_approvals = current_user.sponsored_by_approvals.approved.includes(user: [:avatar_attachment]).limit(20)
    @rejected_approvals = current_user.sponsored_by_approvals.rejected.includes(user: [:avatar_attachment]).limit(20)
  end

  def approve
    if @approval.approve!
      # Create notification for the user
      Notification.create(
        user: @approval.user,
        actor: current_user,
        notifiable: @approval,
        action: 'sponsorship_approved'
      )

      flash[:notice] = "You have approved sponsoring #{@approval.user.username}."
      redirect_back fallback_location: sponsor_approvals_path
    else
      flash[:alert] = "Failed to approve the sponsorship."
      redirect_back fallback_location: root_path
    end
  end

  def reject
    reason = params[:rejection_reason].presence || "No reason provided"
    if @approval.reject!(reason)
      # Create notification for the user
      Notification.create(
        user: @approval.user,
        actor: current_user,
        notifiable: @approval,
        action: 'sponsorship_rejected'
      )

      flash[:notice] = "You have rejected this sponsorship request."
      redirect_to sponsor_approvals_path
    else
      flash[:alert] = "Failed to reject the sponsorship."
      redirect_back fallback_location: root_path
    end
  end

  def reset
    if @approval.reset!
      flash[:notice] = "Decision reset. This sponsorship is pending again."
    else
      flash[:alert] = "Could not reset this sponsorship."
    end
    redirect_to sponsor_approvals_path
  end

  private

  def set_approval
    @approval = SponsorApproval.find_by_friendly_or_id(params[:id])
  end

  def verify_sponsor
    unless @approval.sponsor_id == current_user.id
      flash[:alert] = "You are not authorized to perform this action."
      redirect_to root_path
    end
  end

  def set_approval_with_verify
    @approval = SponsorApproval.find_by_friendly_or_id(params[:id])
    unless @approval
      redirect_to sponsor_approvals_path, alert: "Sponsorship approval request not found." and return
    end
    verify_sponsor
  end
end
