class AddFullSnapshotToMessageLogs < ActiveRecord::Migration[7.2]
  def change
    add_column :message_logs, :message_category_name,       :string
    add_column :message_logs, :flow_item_name,              :string
    add_column :message_logs, :flow_item_icon,              :string
    add_column :message_logs, :flow_item_icon_color,        :string
    add_column :message_logs, :message_category_icon_color, :string
  end
end
