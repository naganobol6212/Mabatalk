class MessageCompletionsController < ApplicationController
  def show
    if user_signed_in?
      last_log = MessageLog.for_viewer(current_user).first
      assign_from_log(last_log) if last_log
    else
      flow_item = FlowItem.find_by(id: session[:last_flow_item_id])
      assign_from_flow_item(flow_item) if flow_item
    end
  end

  private

  def assign_from_log(log)
    @flow_item_name              = log.flow_item_name
    @flow_item_icon              = log.flow_item_icon
    @flow_item_icon_color        = log.flow_item_icon_color
    @message_category_name       = log.message_category_name
  end

  def assign_from_flow_item(flow_item)
    @flow_item_name              = flow_item.name
    @flow_item_icon              = flow_item.icon
    @flow_item_icon_color        = flow_item.icon_color
    @message_category_name       = flow_item.message_category.name
  end
end
