class UsersController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @users = User.search_by_fields(@query, :username, :email)
               .order(Arel.sql("LOWER(username) ASC NULLS LAST"))
  end

  def show
    @user = User.find_by_friendly_or_id(params[:id])
  end

  def following
    @user = User.find_by_friendly_or_id(params[:id])
    @query = params[:q].to_s.strip
    @users = @user.following
               .search_by_fields(@query, :username, :email)
               .order(Arel.sql("LOWER(username) ASC"))
    render 'index'
  end

  def followers
    @user = User.find_by_friendly_or_id(params[:id])
    @query = params[:q].to_s.strip
    @users = @user.followers
               .search_by_fields(@query, :username, :email)
               .order(Arel.sql("LOWER(username) ASC"))
    render 'index'
  end
end
