class AddMessageCategoryIdToFlowItems < ActiveRecord::Migration[7.2]
  def change
    add_reference :flow_items, :message_category, null: true, foreign_key: true
  end
end
