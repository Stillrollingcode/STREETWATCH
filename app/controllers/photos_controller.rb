class PhotosController < ApplicationController
  before_action :set_photo, only: [:show, :edit, :update, :destroy, :remove_tag]
  before_action :authenticate_user!, except: [:index, :show]

  def index
    @photos = Photo.includes(:album, :user, :photographer_user, :riders, :photo_approvals, image_attachment: :blob)

    # Filter by approval status - only show approved photos or user's own photos
    @photos = @photos.select do |photo|
      photo.user == current_user || photo.all_approved?
    end

    # Search
    if params[:search].present?
      @photos = @photos.select do |photo|
        photo.title&.downcase&.include?(params[:search].downcase) ||
        photo.description&.downcase&.include?(params[:search].downcase)
      end
    end

    # Group by photographer
    if params[:group_by] == 'photographer'
      @grouped_photos = @photos.group_by(&:photographer_name)
    end

    # Sort
    @photos = case params[:sort]
    when 'oldest' then @photos.sort_by(&:created_at)
    when 'alphabetical' then @photos.sort_by(&:title)
    when 'by_date' then @photos.select { |p| p.date_taken.present? }.sort_by(&:date_taken).reverse + @photos.select { |p| p.date_taken.blank? }
    else @photos.sort_by(&:created_at).reverse
    end

    # Paginate manually since we're working with an array
    unless params[:group_by]
      page = (params[:page] || 1).to_i
      per_page = 30
      total_count = @photos.count
      @photos = Kaminari.paginate_array(@photos, total_count: total_count).page(page).per(per_page)
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
    params.require(:album).permit(:title, :description, :date)
  end

  def authorize_photo!
    return if @photo.user == current_user

    redirect_to photos_path, alert: 'Not authorized'
  end
end
