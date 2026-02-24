class AllowNullFlowItemIdInMessageLogs < ActiveRecord::Migration[7.2]
  def change
    change_column_null :message_logs, :flow_item_id, true
  end
end
