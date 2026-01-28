class MessageCompletionsController < ApplicationController
  def show
    flow_item_id =
      if user_signed_in?
        MessageLog.order(created_at: :desc).find_by(user: current_user)&.flow_item_id
      else
        session[:last_flow_item_id]
      end

    @flow_item = FlowItem.find(flow_item_id)
    @message_category = @flow_item.message_category
  end
end
