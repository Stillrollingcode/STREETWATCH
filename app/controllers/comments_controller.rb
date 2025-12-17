class CommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_film

  def create
    @comment = @film.comments.build(comment_params)
    @comment.user = current_user

    if @comment.save
      # Redirect to the specific comment with anchor
      if @comment.parent_id.present?
        redirect_to film_path(@film, anchor: "comment-#{@comment.parent_id}"), notice: "Reply posted"
      else
        redirect_to film_path(@film, anchor: "comment-#{@comment.id}"), notice: "Comment posted"
      end
    else
      redirect_to film_path(@film, anchor: "comments"), alert: "Could not post comment: #{@comment.errors.full_messages.join(', ')}"
    end
  end

  def destroy
    @comment = Comment.find_by_friendly_or_id(params[:id])

    # Allow deletion if user is comment author OR film uploader
    if @comment.user == current_user || can_delete_comment?(current_user, @film, @comment)
      @comment.destroy
      redirect_to film_path(@film, anchor: "comments"), notice: "Comment deleted"
    else
      redirect_to film_path(@film, anchor: "comments"), alert: "You don't have permission to delete this comment"
    end
  end

  private

  def set_film
    @film = Film.find_by_friendly_or_id(params[:film_id])
  end

  def comment_params
    params.require(:comment).permit(:body, :parent_id)
  end

  def can_delete_comment?(user, film, comment)
    # Check if current user is the film uploader
    # For now, we'll check if user created the film (created_by could be added as a field)
    # or if the film's filmer_user is the current user
    film.filmer_user == user || film.editor_user == user
  end
end
