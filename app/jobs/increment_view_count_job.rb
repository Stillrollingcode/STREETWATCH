class IncrementViewCountJob < ApplicationJob
  queue_as :default

  # Retry on database deadlocks
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3

  def perform(film_id)
    film = Film.find_by(id: film_id)
    return unless film

    # Increment view count in a single query
    Film.where(id: film_id).update_all("views_count = COALESCE(views_count, 0) + 1")

    # Optional: Log for analytics
    Rails.logger.info "Incremented view count for film ##{film_id} (#{film.title})"
  rescue ActiveRecord::RecordNotFound
    # Film was deleted, no action needed
    Rails.logger.warn "Film ##{film_id} not found for view count increment"
  end
end
