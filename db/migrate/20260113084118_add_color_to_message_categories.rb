class AddColorToMessageCategories < ActiveRecord::Migration[7.2]
  def change
    add_column :message_categories, :color, :string
  end
end
