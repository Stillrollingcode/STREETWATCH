class SearchController < ApplicationController
  respond_to :json

  def index
    query = params[:q].to_s.strip

    if query.blank?
      return respond_to do |format|
        format.json { render json: { films: [], users: [] } }
        format.html { redirect_to root_path }
      end
    end

    # Search films by title, company, description (PostgreSQL & SQLite compatible)
    # Use ILIKE for PostgreSQL, LIKE with LOWER() for SQLite
    if ActiveRecord::Base.connection.adapter_name.downcase == 'postgresql'
      films = Film.where(
        "title ILIKE :q OR company ILIKE :q OR description ILIKE :q",
        q: "%#{query}%"
      ).limit(5).select(:id, :title, :company, :film_type)

      users = User.where(
        "username ILIKE :q OR email ILIKE :q",
        q: "%#{query}%"
      ).limit(5).select(:id, :username, :email)
    else
      # SQLite fallback
      films = Film.where(
        "LOWER(title) LIKE LOWER(:q) OR LOWER(company) LIKE LOWER(:q) OR LOWER(description) LIKE LOWER(:q)",
        q: "%#{query}%"
      ).limit(5).select(:id, :title, :company, :film_type)

      users = User.where(
        "LOWER(username) LIKE LOWER(:q) OR LOWER(email) LIKE LOWER(:q)",
        q: "%#{query}%"
      ).limit(5).select(:id, :username, :email)
    end

    payload = {
      films: films.map { |f| {
        id: f.id,
        title: f.title,
        company: f.company,
        film_type: f.formatted_film_type
      }},
      users: users.map { |u| {
        id: u.id,
        username: u.username,
        email: u.email
      }}
    }

    respond_to do |format|
      format.json { render json: payload }
      format.html { redirect_to root_path }
    end
  end
end
