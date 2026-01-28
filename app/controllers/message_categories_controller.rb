class MessageCategoriesController < ApplicationController
  include MessageCategoriesHelper
  before_action :authenticate_user!, only: %i[new create]

  def index
    @message_categories = MessageCategory.for_user(current_user).order(created_at: :asc)
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

  private

  def message_category_params
    params.require(:message_category)
          .permit(:name, :kana, :icon, :icon_color)
  end
end
