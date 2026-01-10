class AddKeyToCategories < ActiveRecord::Migration[7.2]
  def change
    add_column :categories, :key, :string
    add_index :categories, :key, unique: true
  end
end
