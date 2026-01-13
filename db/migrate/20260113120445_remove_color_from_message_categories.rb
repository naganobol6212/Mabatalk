class RemoveColorFromMessageCategories < ActiveRecord::Migration[7.2]
  def change
    remove_column :message_categories, :color, :string
  end
end
