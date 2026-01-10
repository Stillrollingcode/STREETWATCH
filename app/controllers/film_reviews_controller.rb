class FilmReviewsController < ApplicationController
  before_action :authenticate_user!, except: [:index]
  before_action :set_film
  before_action :set_review, only: [:update, :destroy]

  def index
    @reviews = @film.film_reviews.includes(:user).recent
    render json: @reviews.map { |review| {
      id: review.id,
      user_id: review.user.id,
      username: review.user.username,
      user_name: review.user.name,
      rating: review.rating,
      comment: review.comment,
      created_at: review.created_at,
      can_edit: user_signed_in? && review.user_id == current_user.id
    }}
  end

  def create
    # Check if user already has a review for this film
    existing_review = @film.film_reviews.find_by(user: current_user)

    if existing_review
      # Update existing review instead
      if existing_review.update(review_params)
        render json: {
          id: existing_review.id,
          rating: existing_review.rating,
          comment: existing_review.comment,
          message: 'Review updated successfully'
        }
      else
        render json: { errors: existing_review.errors.full_messages }, status: :unprocessable_entity
      end
    else
      # Create new review
      @review = @film.film_reviews.build(review_params)
      @review.user = current_user

      if @review.save
        render json: {
          id: @review.id,
          rating: @review.rating,
          comment: @review.comment,
          message: 'Review created successfully'
        }, status: :created
      else
        render json: { errors: @review.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end

  def update
    if @review.update(review_params)
      render json: {
        id: @review.id,
        rating: @review.rating,
        comment: @review.comment,
        message: 'Review updated successfully'
      }
    else
      render json: { errors: @review.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @review.destroy
    render json: { message: 'Review deleted successfully' }
  end

  private

  def set_film
    @film = Film.find_by_friendly_or_id(params[:film_id])
    redirect_to films_path, alert: 'Film not found' unless @film
  end

  def set_review
    @review = @film.film_reviews.find_by(id: params[:id], user: current_user)
    render json: { error: 'Review not found or unauthorized' }, status: :not_found unless @review
  end

  def review_params
    params.require(:film_review).permit(:rating, :comment)
  end
end
