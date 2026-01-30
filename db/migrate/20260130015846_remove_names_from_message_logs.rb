class RemoveNamesFromMessageLogs < ActiveRecord::Migration[7.2]
  def change
    remove_column :message_logs, :message_category_name, :string
    remove_column :message_logs, :flow_item_name, :string
  end
end
