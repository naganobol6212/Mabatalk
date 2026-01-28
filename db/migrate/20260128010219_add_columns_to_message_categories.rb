class AddColumnsToMessageCategories < ActiveRecord::Migration[7.2]
  def change
    add_column :message_categories, :key, :string
    add_column :message_categories, :icon_color, :string
    add_column :message_categories, :position, :integer, default: 0, null: false

    change_column_null :message_categories, :user_id, true

    add_index :message_categories, :key, unique: true
  end
end
