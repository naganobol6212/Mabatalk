class MessageCategoriesController < ApplicationController
  include MessageCategoriesHelper
  before_action :authenticate_user!, only: %i[new create edit update destroy copy reorder]
  before_action :set_message_category, only: %i[edit update destroy]

  def index
    @message_categories = MessageCategory.for_user(current_user).order(:position)
  end

  def new
    default_icon = message_category_icons.keys.first
    @message_category = MessageCategory.new(icon: default_icon)
  end

  def copy
    source = MessageCategory.where(user_id: nil).find(params[:id])
    @message_category = MessageCategory.new(
      name: source.name,
      kana: source.kana,
      icon: source.icon,
      icon_color: IconDefinitions::ICON_COLORS.key?(source.icon_color) ? source.icon_color : "gray"
    )
    @source_category_id = source.id
    render :new
  end

  def create
    @message_category =
      current_user.message_categories.build(message_category_params)
    ApplicationRecord.transaction do
      @message_category.save!
      copy_flow_items_from(params[:source_category_id]) if params[:source_category_id].present?
    end

    if params[:source_category_id].present?
      redirect_to message_category_flow_items_path(@message_category),
                  notice: t("message_categories.copy.success")
    else
      redirect_to message_categories_path
    end
  rescue ActiveRecord::RecordInvalid
    @source_category_id = params[:source_category_id]
    render :new, status: :unprocessable_entity
  end

  def edit; end

  def update
    if @message_category.update(message_category_params)
      redirect_to message_categories_path, notice: t("message_categories.update.success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @message_category.destroy!
    redirect_to message_categories_path, notice: t("message_categories.destroy.success")
  rescue ActiveRecord::DeleteRestrictionError
    redirect_to message_categories_path, alert: t("message_categories.destroy.restricted")
  end

  def reorder
    allowed_ids = current_user.message_categories.pluck(:id)
    submitted_ids = params[:ids].map(&:to_i)

    return head :forbidden unless (submitted_ids - allowed_ids).empty?

    system_max = MessageCategory.where(user_id: nil).maximum(:position) || 0

    ActiveRecord::Base.transaction do
      submitted_ids.each_with_index do |id, index|
        current_user.message_categories.find(id).update!(position: system_max + index + 1)
      end
    end

    render json: { status: "ok" }
  end

  private

  def set_message_category
    @message_category = current_user.message_categories.find(params[:id])
  end

  def message_category_params
    params.require(:message_category)
          .permit(:name, :kana, :icon, :icon_color)
  end

  def copy_flow_items_from(source_id)
    source = MessageCategory.where(user_id: nil).find_by(id: source_id)
    return unless source

    source.flow_items.where(user_id: nil).order(:position).each_with_index do |item, idx|
      @message_category.flow_items.create!(
        name: item.name,
        kana: item.kana,
        icon: item.icon,
        icon_color: IconDefinitions::ICON_COLORS.key?(item.icon_color) ? item.icon_color : "gray",
        user: current_user,
        position: idx + 1
      )
    end
  end
end
