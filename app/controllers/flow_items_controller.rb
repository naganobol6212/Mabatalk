class FlowItemsController < ApplicationController
  before_action :authenticate_user!, only: %i[new create edit update destroy reorder]
  before_action :set_message_category, only: %i[index new create edit update destroy]
  before_action :set_flow_item, only: %i[confirm]
  before_action :set_flow_item_for_owner, only: %i[edit update destroy]

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
    @message_category = @flow_item.message_category
  end

  def edit; end

  def update
    if @flow_item.update(flow_item_params)
      redirect_to message_category_flow_items_path(@message_category),
                  notice: t("flow_items.update.success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @flow_item.destroy
    redirect_to message_category_flow_items_path(@message_category),
                notice: t("flow_items.destroy.success")
  end

  def reorder
    @message_category = current_user.message_categories.find(params[:message_category_id])
    scope = @message_category.flow_items.where(user_id: current_user.id)

    allowed_ids = scope.pluck(:id)
    submitted_ids = params[:ids].map(&:to_i)

    return head :forbidden unless (submitted_ids - allowed_ids).empty?

    system_max = @message_category.flow_items.where(user_id: nil).maximum(:position) || 0

    ActiveRecord::Base.transaction do
      submitted_ids.each_with_index do |id, index|
        scope.find(id).update!(position: system_max + index + 1)
      end
    end

    render json: { status: "ok" }
  end

  private

  def set_message_category
    @message_category = MessageCategory.find(params[:message_category_id])
  end

  def set_flow_item
    @flow_item = FlowItem.find(params[:id])
  end

  def set_flow_item_for_owner
    @flow_item = @message_category.flow_items
                                  .where(user: current_user)
                                  .find(params[:id])
  end

  def flow_item_params
    params.require(:flow_item).permit(:name, :kana, :icon, :icon_color)
  end
end
