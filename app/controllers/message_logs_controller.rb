class MessageLogsController < ApplicationController
  before_action :authenticate_user!, only: [ :index ]

  def index
    @message_logs = MessageLog.for_viewer(current_user).includes(:user)
  end

  def create
    flow_item = FlowItem.find_by!(key: params[:flow_item_key])

    if user_signed_in?
      detail_text, detail_data = build_detail_flow(flow_item)
      MessageLog.create!(
        user: current_user,
        flow_item: flow_item,
        detail_flow_text: detail_text,
        detail_flow_data: detail_data
      )
      session.delete(:detail_flow)
      flash[:notice] = t("message_logs.created")
    else
      session[:last_flow_item_key] = flow_item.key
    end

    redirect_to message_completion_path
  end

  private

  def build_detail_flow(flow_item)
    df = session[:detail_flow]
    return [ nil, nil ] unless df&.dig("flow_item_key") == flow_item.key

    answers    = df["answers"] || {}
    definition = DetailFlowDefinitions.find(flow_item.detail_flow_key)
    return [ nil, nil ] unless definition

    parts = definition[:steps].filter_map do |step|
      ans = answers[step[:key]]
      next unless ans
      "#{step[:label]}：#{ans['label']}"
    end

    [ parts.join("、").presence, answers.presence ]
  end
end
