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

    # Search using Searchable concern
    films = Film.search_by_fields(query, :title, :company, :description)
               .limit(5)
               .select(:id, :title, :company, :film_type)

    users = User.search_by_fields(query, :username, :email)
               .limit(5)
               .select(:id, :username, :email)

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
