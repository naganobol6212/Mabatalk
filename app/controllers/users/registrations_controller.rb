class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_account_update_params, only: [:update]

  protected

  def update_resource(resource, params)
    # パスワード変更フォームで新しいパスワードが未入力のまま送信された場合はエラーを返す。
    # （current_password だけ入力して new password が空 → update_without_password で素通りするのを防ぐ）
    if params[:current_password].present? && params[:email].blank? && params[:password].blank?
      resource.errors.add(:password, :blank)
      return false
    end

    if requires_current_password?(params)
      # Deviseのupdate_with_passwordに委譲する前に明示的に検証する。
      # Devise 4.9.x + Rails 7.2 の組み合わせで ActionController::Parameters の
      # delete がシンボル/文字列キーの差異で current_password を取得できない場合の保険。
      current_password = params[:current_password].to_s

      unless resource.valid_password?(current_password)
        resource.errors.add(:current_password, current_password.present? ? :invalid : :blank)
        return false
      end
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
