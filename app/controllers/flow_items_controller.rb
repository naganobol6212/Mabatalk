class FlowItemsController < ApplicationController
  before_action :set_message_category, only: %i[index new create]
  before_action :set_flow_item, only: [ :confirm ]

  def index
    @flow_items =
      @message_category.flow_items
                        .for_user(current_user)
                        .order(:position)
  end

  def new
    @flow_item = @message_category.flow_items.build
  end

  def create
    @flow_item = @message_category.flow_items.build(flow_item_params)
    @flow_item.user = current_user

    last_position = @message_category.flow_items.maximum(:position) || 0
    @flow_item.position = last_position + 1

    if @flow_item.save
      redirect_to message_category_flow_items_path(@message_category)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def confirm
  end

  private

  def set_message_category
    @message_category = MessageCategory.find(params[:message_category_id])
  end

  def set_flow_item
    @flow_item = FlowItem.find(params[:id])
  end

  def flow_item_params
    params.require(:flow_item).permit(:name, :kana, :icon)
  end
end
