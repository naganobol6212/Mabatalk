class MessageLogsController < ApplicationController
  before_action :authenticate_user!, only: [ :index ]

  def index
    @message_logs = MessageLog.for_viewer(current_user)
  end

  def create
  flow_item = FlowItem.find(params[:flow_item_id])
    if user_signed_in?
      MessageLog.create!(
        user: current_user,
        flow_item: flow_item,
        message_category_name: flow_item.message_category.name,
        flow_item_name: flow_item.name
      )
      redirect_to message_completion_path, notice: "ログに自動保存されました"
    else
      session[:last_flow_item_id] = flow_item.id
      redirect_to message_completion_path
    end
  end
end
