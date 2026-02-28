class AddDetailFlowSnapshotToMessageLogs < ActiveRecord::Migration[7.2]
  def up
    add_column :message_logs, :detail_flow_text, :string unless column_exists?(:message_logs, :detail_flow_text)
    add_column :message_logs, :detail_flow_data, :jsonb unless column_exists?(:message_logs, :detail_flow_data)
  end

  def down
    remove_column :message_logs, :detail_flow_text if column_exists?(:message_logs, :detail_flow_text)
    remove_column :message_logs, :detail_flow_data if column_exists?(:message_logs, :detail_flow_data)
  end
end
