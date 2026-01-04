class CategoriesController < ApplicationController
  def index
    @categories = Category
      .for_user(current_user)
      .order(:position)
  end
end
