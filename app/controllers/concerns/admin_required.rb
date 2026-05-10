module AdminRequired
  extend ActiveSupport::Concern

  included do
    before_action :require_admin
  end

  private

  def require_admin
    raise ActionController::RoutingError, "Not Found" unless current_user&.admin?
  end
end
