class RemoveCategoryIdFromFlowItems < ActiveRecord::Migration[7.2]
  def change
    remove_reference :flow_items, :category, foreign_key: true
  end
end
