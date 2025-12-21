class PhotoCommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_photo
  before_action :set_comment, only: [:edit, :update, :destroy]

  def create
    @comment = @photo.photo_comments.build(comment_params)
    @comment.user = current_user

    if @comment.save
      redirect_to @photo, notice: 'Comment added.'
    else
      redirect_to @photo, alert: 'Failed to add comment.'
    end
  end

  def edit
    authorize_comment!
  end

  def update
    authorize_comment!
    if @comment.update(comment_params)
      redirect_to @photo, notice: 'Comment updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize_comment!
    @comment.destroy
    redirect_to @photo, notice: 'Comment deleted.'
  end

  private

  def set_photo
    @photo = Photo.find_by_friendly_or_id(params[:photo_id])
    redirect_to photos_path, alert: 'Photo not found' unless @photo
  end

  def set_comment
    @comment = PhotoComment.find_by_friendly_or_id(params[:id])
    redirect_to @photo, alert: 'Comment not found' unless @comment
  end

  def comment_params
    params.require(:photo_comment).permit(:body, :parent_id)
  end

  def authorize_comment!
    return if @comment.user == current_user

    redirect_to @photo, alert: 'Not authorized'
  end
end
