class FlowItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_category, only: [:new, :create]
  before_action :set_flow_item, only: [:confirm]

  def new
    @flow_item = @category.flow_items.build
  end

  def create
    @flow_item = @category.flow_items.build(flow_item_params)

    last_position = @category.flow_items.maximum(:position) || 0
    @flow_item.position = last_position + 1

    if @flow_item.save
      redirect_to category_flow_path(@category)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def confirm
  end

  private

  def set_category
    @category = Category.find(params[:category_id])
  end

  def set_flow_item
    @flow_item = FlowItem.find(params[:id])
  end

  def flow_item_params
    params.require(:flow_item).permit(:name, :kana, :icon)
  end
end
