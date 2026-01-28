class HomesController < ApplicationController
  def top
    redirect_to message_categories_path if current_user
  end
end
