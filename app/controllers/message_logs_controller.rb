class MessageLogsController < ApplicationController
  def create
    return redirect_to message_completion_path unless user_signed_in?
    flow_item = FlowItem.find(params[:flow_item_id])
    message_log = MessageLog.new(
      flow_item: flow_item,
      user: current_user
    )
    message_log.save
    redirect_to message_completion_path, status: :see_other
  end
end
