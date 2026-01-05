class FlowItemsController < ApplicationController
  def confirm
    @flow_item = FlowItem.find(params[:id])
  end
end
