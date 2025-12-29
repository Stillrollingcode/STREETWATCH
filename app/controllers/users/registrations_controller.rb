class Users::RegistrationsController < Devise::RegistrationsController
  protected

  # Allow profile updates (avatar/bio/etc.) without forcing password entry unless changing sensitive fields.
  def update_resource(resource, params)
    changing_password = params[:password].present? || params[:password_confirmation].present?
    changing_email = params[:email].present? && params[:email] != resource.email

    # Extract sponsor_ids before calling update
    sponsor_ids = params[:sponsor_ids]&.map(&:to_i) || []
    params.delete(:sponsor_ids)

    # Update user resource first
    result = if changing_password || changing_email
      super
    else
      params.delete(:current_password)
      resource.update_without_password(params)
    end

    # Handle sponsor approvals after successful update
    if result && sponsor_ids.any?
      handle_sponsor_approvals(resource, sponsor_ids)
    elsif sponsor_ids.empty?
      # If no sponsors selected, remove all pending approvals
      handle_sponsor_approvals(resource, [])
    end

    result
  end

  # Redirect back to referer (profile page or settings page) after update
  def after_update_path_for(resource)
    # If came from user profile, go back to profile; otherwise go to settings
    if request.referer.present? && request.referer.include?('/users/')
      stored_location_for(resource) || request.referer
    else
      settings_path
    end
  end

  private

  def handle_sponsor_approvals(user, sponsor_ids)
    # Get current pending and approved sponsor approval IDs
    current_pending_ids = user.sponsor_approvals.pending.pluck(:sponsor_id)
    current_approved_ids = user.sponsor_approvals.approved.pluck(:sponsor_id)
    current_all_ids = current_pending_ids + current_approved_ids

    # Find sponsors to remove (only remove pending ones, keep approved)
    sponsors_to_remove = current_pending_ids - sponsor_ids
    user.sponsor_approvals.pending.where(sponsor_id: sponsors_to_remove).destroy_all

    # Find new sponsors to add
    new_sponsor_ids = sponsor_ids - current_all_ids

    # Create approval requests for new sponsors
    new_sponsor_ids.each do |sponsor_id|
      sponsor = User.find_by(id: sponsor_id)
      next unless sponsor && sponsor.company_type?

      SponsorApproval.create(
        user: user,
        sponsor: sponsor,
        status: 'pending'
      )

      # Create notification for the sponsor
      Notification.create(
        user: sponsor,
        actor: user,
        notifiable: user,
        action: 'sponsorship_requested'
      )
    end
  end
end
