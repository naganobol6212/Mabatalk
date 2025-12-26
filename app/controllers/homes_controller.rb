class HomesController < ApplicationController
  def top
    redirect_to categories_path if current_user
  end
end
