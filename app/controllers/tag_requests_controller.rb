class TagRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_film, only: [:create]
  before_action :set_tag_request, only: [:approve, :deny]
  before_action :authorize_film_owner!, only: [:approve, :deny]

  def create
    # Check if user is already tagged in this role
    if already_tagged?
      redirect_to @film, alert: "You are already tagged as #{params[:role]} in this film."
      return
    end

    # Check if there's already a pending request
    existing_request = @film.tag_requests.find_by(requester: current_user, role: params[:role])
    if existing_request&.pending?
      redirect_to @film, alert: "You already have a pending request for this role."
      return
    end

    @tag_request = @film.tag_requests.build(tag_request_params)
    @tag_request.requester = current_user
    @tag_request.status = 'pending'

    if @tag_request.save
      # Create notification for film owner
      Notification.create!(
        user: @film.user,
        actor: current_user,
        notifiable: @tag_request,
        action: 'tag_requested'
      )

      redirect_to @film, notice: "Tag request submitted! The film uploader will be notified."
    else
      redirect_to @film, alert: "Unable to submit tag request: #{@tag_request.errors.full_messages.join(', ')}"
    end
  end

  def approve
    if @tag_request.approve!
      # Create notification for requester
      Notification.create!(
        user: @tag_request.requester,
        actor: current_user,
        notifiable: @tag_request,
        action: 'tag_request_approved'
      )

      redirect_to @film, notice: "Tag request approved! #{@tag_request.requester.username} has been added as #{@tag_request.role}."
    else
      redirect_to @film, alert: "Unable to approve tag request."
    end
  end

  def deny
    if @tag_request.deny!
      # Create notification for requester
      Notification.create!(
        user: @tag_request.requester,
        actor: current_user,
        notifiable: @tag_request,
        action: 'tag_request_denied'
      )

      redirect_to @film, notice: "Tag request denied."
    else
      redirect_to @film, alert: "Unable to deny tag request."
    end
  end

  private

  def set_film
    @film = Film.find_by_friendly_or_id(params[:film_id])
  end

  def set_tag_request
    @tag_request = TagRequest.find(params[:id])
    @film = @tag_request.film
  end

  def authorize_film_owner!
    unless @film.user_id == current_user.id
      redirect_to @film, alert: "You are not authorized to manage tag requests for this film."
    end
  end

  def tag_request_params
    params.require(:tag_request).permit(:role, :message)
  end

  def already_tagged?
    case params[:tag_request][:role]
    when 'rider'
      @film.riders.include?(current_user)
    when 'filmer'
      @film.filmers.include?(current_user) || @film.filmer_user == current_user
    when 'company'
      @film.companies.include?(current_user) || @film.company_user == current_user
    when 'editor'
      @film.editor_user == current_user
    else
      false
    end
  end
end
