class MessageCategoriesController < ApplicationController
  before_action :authenticate_user!

  def new
    @message_category = MessageCategory.new(icon: "local_cafe")
  end

  def create
    @message_category =
      current_user.message_categories.build(message_category_params)

    if @message_category.save
      redirect_to categories_path
    else
      render :new
    end
  end

  private

  def message_category_params
    params.require(:message_category)
          .permit(:name, :kana, :icon)
  end
end
