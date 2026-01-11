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
        flow_item: flow_item
      )
    else
      session[:last_flow_item_id] = flow_item.id
    end

    redirect_to message_completion_path, notice: "ログに自動保存されました"
  end
end
