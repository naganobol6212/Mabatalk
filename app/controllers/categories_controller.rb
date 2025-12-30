class CategoriesController < ApplicationController
  def index
    @categories = Category.order(:position)
  end
end
