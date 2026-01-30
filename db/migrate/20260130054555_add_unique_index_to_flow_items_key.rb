class AddUniqueIndexToFlowItemsKey < ActiveRecord::Migration[7.2]
  def change
    add_index :flow_items, :key, unique: true
  end
end