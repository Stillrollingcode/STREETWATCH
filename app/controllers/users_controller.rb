class UsersController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @users = User.all

    if @query.present?
      if ActiveRecord::Base.connection.adapter_name.downcase == 'postgresql'
        @users = @users.where("username ILIKE :q OR email ILIKE :q", q: "%#{@query}%")
      else
        @users = @users.where("LOWER(username) LIKE :q OR LOWER(email) LIKE :q", q: "%#{@query.downcase}%")
      end
    end

    @users = @users.order(Arel.sql("LOWER(username) ASC NULLS LAST"))
  end

  def show
    @user = User.find_by_friendly_or_id(params[:id])
  end

  def following
    @user = User.find_by_friendly_or_id(params[:id])
    @query = params[:q].to_s.strip
    @users = @user.following

    if @query.present?
      if ActiveRecord::Base.connection.adapter_name.downcase == 'postgresql'
        @users = @users.where("username ILIKE :q OR email ILIKE :q", q: "%#{@query}%")
      else
        @users = @users.where("LOWER(username) LIKE :q OR LOWER(email) LIKE :q", q: "%#{@query.downcase}%")
      end
    end

    @users = @users.order(Arel.sql("LOWER(username) ASC"))
    render 'index'
  end

  def followers
    @user = User.find_by_friendly_or_id(params[:id])
    @query = params[:q].to_s.strip
    @users = @user.followers

    if @query.present?
      if ActiveRecord::Base.connection.adapter_name.downcase == 'postgresql'
        @users = @users.where("username ILIKE :q OR email ILIKE :q", q: "%#{@query}%")
      else
        @users = @users.where("LOWER(username) LIKE :q OR LOWER(email) LIKE :q", q: "%#{@query.downcase}%")
      end
    end

    @users = @users.order(Arel.sql("LOWER(username) ASC"))
    render 'index'
  end
end
