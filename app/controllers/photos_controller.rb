class PhotosController < ApplicationController
  before_action :set_photo, only: [:show, :edit, :update, :destroy, :remove_tag, :hide_from_profile, :unhide_from_profile]
  before_action :authenticate_user!, except: [:index, :show]

  def index
    # Set cache headers for CDN (5 minutes for logged-out users)
    expires_in 5.minutes, public: true unless user_signed_in?

    @photos = Photo.includes(:album, :user, :photographer_user, :riders, image_attachment: :blob)

    # Filter by approval status - only show fully approved photos or user's own photos
    # Use SQL for performance instead of loading all records
    if user_signed_in?
      @photos = @photos.where(
        "photos.user_id = ? OR NOT EXISTS (
          SELECT 1 FROM photo_approvals
          WHERE photo_approvals.photo_id = photos.id
          AND photo_approvals.status = 'pending'
        )",
        current_user.id
      )
    else
      @photos = @photos.where(
        "NOT EXISTS (
          SELECT 1 FROM photo_approvals
          WHERE photo_approvals.photo_id = photos.id
          AND photo_approvals.status = 'pending'
        )"
      )
    end

    # Search using SQL
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @photos = @photos.where(
        "photos.title ILIKE ? OR photos.description ILIKE ?",
        search_term, search_term
      )
    end

    # Group by photographer or albums
    if params[:group_by] == 'photographer'
      # Limit for performance
      @grouped_photos = @photos.limit(200).to_a.group_by(&:photographer_name)
    elsif params[:group_by] == 'albums'
      # Show all public albums plus user's own albums
      @albums = Album.includes(:user, photos: :image_attachment)
      if user_signed_in?
        @albums = @albums.where('is_public = ? OR user_id = ?', true, current_user.id)
      else
        @albums = @albums.where(is_public: true)
      end
      @albums = @albums.recent.limit(100)
    end

    # Sort using SQL when possible
    unless params[:group_by] == 'photographer'
      @photos = case params[:sort]
      when 'oldest' then @photos.order(created_at: :asc)
      when 'alphabetical' then @photos.order(Arel.sql('LOWER(title) ASC'))
      when 'by_date' then @photos.order(Arel.sql('date_taken DESC NULLS LAST'))
      else @photos.order(created_at: :desc)
      end

      # Paginate to 18 photos per page (3 columns × 6 rows)
      @photos = @photos.page(params[:page]).per(18)
    end
  end

  def show
    unless @photo.viewable_by?(current_user)
      redirect_to photos_path, alert: 'This photo is pending approval and not yet visible to the public.'
      return
    end

    @photo_comment = PhotoComment.new
    @comments = @photo.photo_comments.top_level.includes(:user, :replies)
  end

  def new
    @album = params[:album_id] ? Album.find_by_friendly_or_id(params[:album_id]) : nil
    @photo = current_user.photos.build(album: @album)
  end

  def create
    @photo = current_user.photos.build(photo_params)
    if @photo.save
      redirect_to @photo, notice: 'Photo uploaded successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def batch_upload
    @album = params[:album_id] ? Album.find_by_friendly_or_id(params[:album_id]) : nil
    @albums = current_user.albums.order(:title)
  end

  def batch_create
    # Create or find album
    album = if params[:album_id].present?
              Album.find_by_friendly_or_id(params[:album_id])
            elsif params[:album].present? && params[:album][:title].present?
              current_user.albums.create!(album_params)
            else
              return redirect_to batch_upload_photos_path, alert: 'Please select or create an album'
            end

    unless album
      return redirect_to batch_upload_photos_path, alert: 'Album not found'
    end

    # Upload photos
    uploaded_count = 0
    errors = []

    if params[:photos].present? && params[:photos][:images].present?
      params[:photos][:images].each_with_index do |image_file, index|
        next if image_file.blank?

        photo_title = params[:photos][:titles]&.dig(index.to_s).presence || image_file.original_filename
        photo_description = params[:photos][:descriptions]&.dig(index.to_s).presence

        # Get per-photo tags if available
        date_taken = params[:photos][:dates_taken]&.dig(index.to_s).presence
        photographer_id = params[:photos][:photographer_ids]&.dig(index.to_s).presence
        custom_photographer = params[:photos][:custom_photographers]&.dig(index.to_s).presence
        company_id = params[:photos][:company_ids]&.dig(index.to_s).presence
        rider_ids = params[:photos][:rider_ids]&.dig(index.to_s)

        photo = album.photos.new(
          user: current_user,
          title: photo_title,
          description: photo_description,
          date_taken: date_taken,
          photographer_user_id: photographer_id,
          company_user_id: company_id,
          custom_photographer_name: custom_photographer,
          image: image_file
        )

        # Add riders for this specific photo
        if rider_ids.present?
          photo.rider_ids = rider_ids.reject(&:blank?)
        end

        if photo.save
          uploaded_count += 1
        else
          errors << "#{photo_title}: #{photo.errors.full_messages.join(', ')}"
        end
      end
    end

    if uploaded_count > 0
      message = "Successfully uploaded #{uploaded_count} photo#{'s' if uploaded_count != 1}."
      message += " #{errors.count} failed." if errors.any?
      redirect_to album, notice: message
    else
      redirect_to batch_upload_photos_path(album_id: album.to_param), alert: "Failed to upload photos. #{errors.join('; ')}"
    end
  end

  def edit
    authorize_photo!
  end

  def update
    authorize_photo!
    if @photo.update(photo_params)
      redirect_to @photo, notice: 'Photo updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize_photo!
    album = @photo.album
    @photo.destroy
    redirect_to album, notice: 'Photo deleted successfully.'
  end

  def remove_tag
    authorize_photo!
    tag_type = params[:tag_type]
    tag_id = params[:tag_id]

    case tag_type
    when 'rider'
      rider = @photo.riders.find_by(id: tag_id)
      if rider
        @photo.riders.delete(rider)
        # Remove associated approval
        @photo.photo_approvals.where(approver_id: tag_id, approval_type: 'rider').destroy_all
        redirect_to @photo, notice: 'Rider tag removed successfully.'
      else
        redirect_to @photo, alert: 'Rider not found.'
      end
    when 'photographer'
      if @photo.photographer_user_id.to_s == tag_id.to_s
        @photo.update(photographer_user_id: nil)
        # Remove associated approval
        @photo.photo_approvals.where(approver_id: tag_id, approval_type: 'photographer').destroy_all
        redirect_to @photo, notice: 'Photographer tag removed successfully.'
      else
        redirect_to @photo, alert: 'Photographer not found.'
      end
    when 'company'
      if @photo.company_user_id.to_s == tag_id.to_s
        @photo.update(company_user_id: nil)
        # Remove associated approval
        @photo.photo_approvals.where(approver_id: tag_id, approval_type: 'company').destroy_all
        redirect_to @photo, notice: 'Company tag removed successfully.'
      else
        redirect_to @photo, alert: 'Company not found.'
      end
    else
      redirect_to @photo, alert: 'Invalid tag type.'
    end
  end

  def hide_from_profile
    current_user.hide_photo_from_profile(@photo)
    respond_to do |format|
      format.html { redirect_to user_path(current_user), notice: "Photo hidden from your profile." }
      format.turbo_stream
    end
  end

  def unhide_from_profile
    current_user.unhide_photo_from_profile(@photo)
    respond_to do |format|
      format.html { redirect_to user_path(current_user), notice: "Photo restored to your profile." }
      format.turbo_stream
    end
  end

  private

  def set_photo
    @photo = Photo.find_by_friendly_or_id(params[:id])
    redirect_to photos_path, alert: 'Photo not found' unless @photo
  end

  def photo_params
    params.require(:photo).permit(:title, :description, :date_taken, :album_id,
                                  :photographer_user_id, :company_user_id,
                                  :custom_photographer_name, :custom_riders,
                                  :image, rider_ids: [])
  end

  def album_params
    params.require(:album).permit(:title, :description, :date, :is_public)
  end

  def authorize_photo!
    return if @photo.user == current_user

    redirect_to photos_path, alert: 'Not authorized'
  end
end
