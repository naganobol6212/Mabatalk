class RenameFlowItemsColorToIconColor < ActiveRecord::Migration[7.2]
  def change
    rename_column :flow_items, :color, :icon_color
  end
end
