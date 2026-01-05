class CategoryFlowsController < ApplicationController
  def show
    @category = Category
      .for_user(current_user)
      .find(params[:category_id])

    @items = @category.flow_items
      .for_user(current_user)
      .order(:position)
  end
end
