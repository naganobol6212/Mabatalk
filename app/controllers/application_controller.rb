class ApplicationController < ActionController::Base
  def after_sign_in_path_for(resource)
    categories_path
  end
  def after_sign_up_path_for(resource)
    categories_path
  end

  allow_browser versions: :modern
end
