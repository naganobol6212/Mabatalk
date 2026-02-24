class AddFullSnapshotToMessageLogs < ActiveRecord::Migration[7.2]
  def up
    add_column :message_logs, :message_category_name,       :string unless column_exists?(:message_logs, :message_category_name)
    add_column :message_logs, :flow_item_name,              :string unless column_exists?(:message_logs, :flow_item_name)
    add_column :message_logs, :flow_item_icon,              :string unless column_exists?(:message_logs, :flow_item_icon)
    add_column :message_logs, :flow_item_icon_color,        :string unless column_exists?(:message_logs, :flow_item_icon_color)
    add_column :message_logs, :message_category_icon_color, :string unless column_exists?(:message_logs, :message_category_icon_color)
  end

  def down
    remove_column :message_logs, :flow_item_icon              if column_exists?(:message_logs, :flow_item_icon)
    remove_column :message_logs, :flow_item_icon_color        if column_exists?(:message_logs, :flow_item_icon_color)
    remove_column :message_logs, :message_category_icon_color if column_exists?(:message_logs, :message_category_icon_color)
  end
end
