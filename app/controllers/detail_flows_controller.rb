class DetailFlowsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_flow_item
  before_action :verify_system_flow_item
  before_action :set_flow_definition

  def show
    @step_index = params[:step_index].to_i
    @step       = @flow_definition[:steps][@step_index]

    if session.dig(:detail_flow, "flow_item_key") != @flow_item.key
      session[:detail_flow] = { "flow_item_key" => @flow_item.key, "answers" => {} }
    end

    answered_count = session.dig(:detail_flow, "answers")&.size || 0
    if @step_index > answered_count
      redirect_to detail_flow_step_path(@flow_item.key, answered_count) and return
    end

    redirect_to message_categories_path if @step.nil?
  end

  def submit
    @step_index = params[:step_index].to_i
    @step       = @flow_definition[:steps][@step_index]

    if params[:answer].blank?
      flash.now[:alert] = t("detail_flows.answer_required")
      render :show and return
    end

    session[:detail_flow] ||= { "flow_item_key" => @flow_item.key, "answers" => {} }
    session[:detail_flow]["answers"][@step[:key]] = {
      "value" => params[:answer],
      "label" => @step[:choices].find { |c| c[:value] == params[:answer] }&.dig(:label)
    }

    next_index = @step_index + 1

    if next_index < @flow_definition[:steps].length
      redirect_to detail_flow_step_path(@flow_item.key, next_index)
    else
      if user_signed_in?
        answers = session[:detail_flow]&.dig("answers") || {}
        parts = @flow_definition[:steps].filter_map do |step|
          ans = answers[step[:key]]
          next unless ans
          "#{step[:label]}：#{ans['label']}"
        end
        MessageLog.create!(
          user: current_user,
          flow_item: @flow_item,
          detail_flow_text: parts.join("、").presence,
          detail_flow_data: answers.presence
        )
        session.delete(:detail_flow)
        flash[:notice] = t("message_logs.created")
      else
        session[:last_flow_item_key] = @flow_item.key
      end
      redirect_to message_completion_path
    end
  end

  private

  def set_flow_item
    @flow_item = FlowItem.find_by!(key: params[:flow_item_key])
  end

  def verify_system_flow_item
    redirect_to message_categories_path unless @flow_item.user_id.nil?
  end

  def set_flow_definition
    @flow_definition = DetailFlowDefinitions.find(@flow_item.detail_flow_key)
    redirect_to message_categories_path if @flow_definition.nil?
  end
end
