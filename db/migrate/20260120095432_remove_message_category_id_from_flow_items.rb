class RemoveMessageCategoryIdFromFlowItems < ActiveRecord::Migration[7.2]
  def change
    remove_reference :flow_items, :message_category, null: false, foreign_key: true
  end
end
