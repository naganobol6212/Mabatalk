class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_account_update_params, only: [:update]

  protected

  def update_resource(resource, params)
    if requires_current_password?(params)
      resource.update_with_password(params)
    else
      params.delete(:current_password)
      resource.update_without_password(params)
    end
  end

  def configure_account_update_params
    devise_parameter_sanitizer.permit(
      :account_update,
      keys: [ :name, :email, :password, :password_confirmation, :current_password ]
    )
  end

  def after_update_path_for(_resource)
    settings_path
  end

  private

  def requires_current_password?(params)
    params[:password].present? ||
      (params[:email].present? && params[:email] != resource.email)
  end
end
