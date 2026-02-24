class AddSnapshotFieldsToMessageLogs < ActiveRecord::Migration[7.2]
  def change
    add_column :message_logs, :message_category_name, :string, null: false, default: ""
    add_column :message_logs, :flow_item_name, :string, null: false, default: ""
  end
end
