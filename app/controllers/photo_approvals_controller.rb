class PhotoApprovalsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_approval, only: [:approve, :reject]
  before_action :verify_approver, only: [:approve, :reject]
  before_action :set_approval_with_verify, only: [:reset]

  def index
    @pending_approvals = current_user.photo_approvals.pending.includes(photo: [:image_attachment])
    @approved_approvals = current_user.photo_approvals.approved.includes(photo: [:image_attachment]).limit(20)
    @rejected_approvals = current_user.photo_approvals.rejected.includes(photo: [:image_attachment]).limit(20)
  end

  def approve
    @approval.approve!

    # Create notification for the photo uploader
    if @approval.photo.user
      Notification.create(
        user: @approval.photo.user,
        actor: current_user,
        notifiable: @approval,
        action: 'tag_approved'
      )
    end

    flash[:notice] = "You have approved this photo. It will be published once all tagged users approve."
    redirect_back fallback_location: photo_approvals_path
  rescue ActiveRecord::RecordInvalid => e
    flash[:alert] = "Failed to approve the photo: #{e.message}"
    redirect_back fallback_location: root_path
  end

  def reject
    reason = params[:rejection_reason].presence || "No reason provided"
    @approval.reject!(reason)

    # Create notification for the photo uploader
    if @approval.photo.user
      Notification.create(
        user: @approval.photo.user,
        actor: current_user,
        notifiable: @approval,
        action: 'tag_rejected'
      )
    end

    flash[:notice] = "You have rejected this photo tag."
    redirect_to photo_approvals_path
  rescue ActiveRecord::RecordInvalid => e
    flash[:alert] = "Failed to reject the photo: #{e.message}"
    redirect_back fallback_location: root_path
  end

  def reset
    @approval.reset!
    flash[:notice] = "Decision reset. This tag is pending again."
    redirect_to photo_approvals_path
  rescue ActiveRecord::RecordInvalid => e
    flash[:alert] = "Failed to reset the photo tag: #{e.message}"
    redirect_back fallback_location: root_path
  end

  private

  def set_approval
    @approval = PhotoApproval.find_by_friendly_or_id(params[:id])
    redirect_to photos_path, alert: 'Approval request not found' unless @approval
  end

  def verify_approver
    unless @approval&.approver_id == current_user.id
      flash[:alert] = "You are not authorized to perform this action."
      redirect_to root_path
    end
  end

  def set_approval_with_verify
    @approval = PhotoApproval.find_by_friendly_or_id(params[:id])
    unless @approval
      redirect_to photo_approvals_path, alert: 'Approval request not found' and return
    end
    verify_approver
  end
end
