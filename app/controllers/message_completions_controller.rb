class MessageCompletionsController < ApplicationController
  def show
    @flow_item = FlowItem.find(params[:flow_item_id])
  end
end
