class AddDetailFlowKeyToFlowItems < ActiveRecord::Migration[7.2]
  def up
    add_column :flow_items, :detail_flow_key, :string unless column_exists?(:flow_items, :detail_flow_key)
  end

  def down
    remove_column :flow_items, :detail_flow_key if column_exists?(:flow_items, :detail_flow_key)
  end
end
