class MessageLogsController < ApplicationController
  def create
  flow_item = FlowItem.find(params[:flow_item_id])

    if user_signed_in?
      MessageLog.create!(
        user: current_user,
        flow_item: flow_item
      )
    else
      session[:last_flow_item_id] = flow_item.id
    end

    redirect_to message_completion_path
  end
end
