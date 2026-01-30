class RemoveNamesFromMessageLogs < ActiveRecord::Migration[7.2]
  def change
    remove_column :message_logs, :message_category_name if column_exists?(:message_logs, :message_category_name)
    remove_column :message_logs, :flow_item_name if column_exists?(:message_logs, :flow_item_name)
  end
end
