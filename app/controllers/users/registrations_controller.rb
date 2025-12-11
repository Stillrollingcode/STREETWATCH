class Users::RegistrationsController < Devise::RegistrationsController
  protected

  # Allow profile updates (avatar/bio/etc.) without forcing password entry unless changing sensitive fields.
  def update_resource(resource, params)
    changing_password = params[:password].present? || params[:password_confirmation].present?
    changing_email = params[:email].present? && params[:email] != resource.email

    if changing_password || changing_email
      super
    else
      params.delete(:current_password)
      resource.update_without_password(params)
    end
  end
end
