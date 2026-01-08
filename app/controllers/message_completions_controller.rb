class MessageCompletionsController < ApplicationController
  def show
    if user_signed_in?
      @flow_item =
        current_user.message_logs.order(created_at: :desc).first&.flow_item
    else
      @flow_item = FlowItem.find_by(id: session[:last_flow_item_id])
    end
  end
end
