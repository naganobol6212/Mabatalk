class CreateCategories < ActiveRecord::Migration[7.2]
  def change
    create_table :categories do |t|
      t.string  :title,    null: false
      t.string  :ruby,     null: false
      t.string  :icon,     null: false
      t.string  :color,    null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end
end
