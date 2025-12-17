class FilmApprovalsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_approval, only: [:approve, :reject]
  before_action :verify_approver, only: [:approve, :reject]

  def index
    @pending_approvals = current_user.film_approvals.pending.includes(film: [:thumbnail_attachment])
    @approved_approvals = current_user.film_approvals.approved.includes(film: [:thumbnail_attachment]).limit(20)
    @rejected_approvals = current_user.film_approvals.rejected.includes(film: [:thumbnail_attachment]).limit(20)
  end

  def approve
    if @approval.approve!
      flash[:notice] = "You have approved this film. It will be published once all tagged users approve."
      redirect_to film_path(@approval.film)
    else
      flash[:alert] = "Failed to approve the film."
      redirect_back fallback_location: root_path
    end
  end

  def reject
    reason = params[:rejection_reason].presence || "No reason provided"
    if @approval.reject!(reason)
      flash[:notice] = "You have rejected this film tag."
      redirect_to film_approvals_path
    else
      flash[:alert] = "Failed to reject the film."
      redirect_back fallback_location: root_path
    end
  end

  private

  def set_approval
    @approval = FilmApproval.find_by_friendly_or_id(params[:id])
  end

  def verify_approver
    unless @approval.approver_id == current_user.id
      flash[:alert] = "You are not authorized to perform this action."
      redirect_to root_path
    end
  end
end
