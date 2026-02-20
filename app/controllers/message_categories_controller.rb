class MessageCategoriesController < ApplicationController
  include MessageCategoriesHelper
  before_action :authenticate_user!, only: %i[new create destroy]

  def index
    @message_categories = MessageCategory.for_user(current_user).order(:position)
  end

  def new
    default_icon = message_category_icons.keys.first
    @message_category = MessageCategory.new(icon: default_icon)
  end

  def create
    @message_category =
      current_user.message_categories.build(message_category_params)

    if @message_category.save
      redirect_to message_categories_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @message_category = current_user.message_categories.find(params[:id])
    @message_category.destroy!
    redirect_to message_categories_path, notice: t("message_categories.destroy.success")
  rescue ActiveRecord::DeleteRestrictionError
    redirect_to message_categories_path, alert: t("message_categories.destroy.restricted")
  end

  private

  def message_category_params
    params.require(:message_category)
          .permit(:name, :kana, :icon, :icon_color)
  end
end
