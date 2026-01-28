class AddMessageCategoryToFlowItems < ActiveRecord::Migration[7.2]
  def change
    add_reference :flow_items,
                  :message_category,
                  foreign_key: true,
                  index: true
  end
end
