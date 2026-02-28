class MessageCompletionsController < ApplicationController
  def show
    if user_signed_in?
      last_log = MessageLog.for_viewer(current_user).first
      assign_from_log(last_log) if last_log
    else
      flow_item = FlowItem.find_by(key: session[:last_flow_item_key])
      assign_from_flow_item(flow_item) if flow_item
    end
  end

  private

  def assign_from_log(log)
    @flow_item_name              = log.flow_item_name
    @flow_item_icon              = log.flow_item_icon
    @flow_item_icon_color        = log.flow_item_icon_color
    @message_category_name       = log.message_category_name
    @detail_flow_text            = log.detail_flow_text
  end

  def assign_from_flow_item(flow_item)
    @flow_item_name              = flow_item.name
    @flow_item_icon              = flow_item.icon
    @flow_item_icon_color        = flow_item.icon_color
    @message_category_name       = flow_item.message_category.name
    @detail_flow_text            = build_detail_flow_text_from_session(flow_item)
  end

  def build_detail_flow_text_from_session(flow_item)
    df = session[:detail_flow]
    return nil unless df&.dig("flow_item_key") == flow_item.key

    answers    = df["answers"] || {}
    definition = DetailFlowDefinitions.find(flow_item.detail_flow_key)
    return nil unless definition

    parts = definition[:steps].filter_map do |step|
      ans = answers[step[:key]]
      next unless ans
      "#{step[:label]}：#{ans['label']}"
    end

    parts.join("、").presence
  end
end
