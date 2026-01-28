class CommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_film

  def create
    @comment = @film.comments.build(comment_params)
    @comment.user = current_user

    if @comment.save
      respond_to do |format|
        format.turbo_stream
        format.html do
          if @comment.parent_id.present?
            redirect_to film_path(@film, anchor: "comment-#{@comment.parent_id}"), notice: "Reply posted"
          else
            redirect_to film_path(@film, anchor: "comment-#{@comment.id}"), notice: "Comment posted"
          end
        end
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "comment-form-errors",
            "<p style='color: var(--error); font-size: 14px; margin-bottom: 12px;'>#{@comment.errors.full_messages.join(', ')}</p>"
          )
        end
        format.html do
          redirect_to film_path(@film, anchor: "comments"), alert: "Could not post comment: #{@comment.errors.full_messages.join(', ')}"
        end
      end
    end
  end

  def destroy
    @comment = Comment.find_by_friendly_or_id(params[:id])
    @parent_id = @comment.parent_id

    # Allow deletion if user is comment author OR film uploader
    if @comment.user == current_user || can_delete_comment?(current_user, @film, @comment)
      @comment.destroy
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to film_path(@film, anchor: "comments"), notice: "Comment deleted" }
      end
    else
      redirect_to film_path(@film, anchor: "comments"), alert: "You don't have permission to delete this comment"
    end
  end

  def like
    @comment = Comment.find_by_friendly_or_id(params[:id])
    @like = @comment.comment_likes.find_or_initialize_by(user: current_user)

    if @like.persisted?
      @like.destroy
      @liked = false
    else
      @like.save
      @liked = true
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to film_path(@film, anchor: "comment-#{@comment.id}") }
    end
  end

  private

  def set_film
    @film = Film.find_by_friendly_or_id(params[:film_id])
  end

  def comment_params
    params.require(:comment).permit(:body, :parent_id)
  end
end
