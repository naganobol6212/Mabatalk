class CategoryFlowsController < ApplicationController
  def show
    @category = Category.find(params[:category_id])

    @items =
      if current_user
        @category.flow_items.where(user_id: current_user.id).order(:position)
      else
        @category.flow_items.where(user_id: nil).order(:position)
      end

    selected_key = params[:item].presence
    @selected_item = @items.find { |item| item.key == selected_key }
  end
end
