class CategoriesController < ApplicationController
  def index
    default_categories =
      Category.for_user(current_user).order(:position)

    user_categories =
      current_user ? current_user.message_categories.order(:created_at) : []

    @categories = default_categories + user_categories
  end
end
