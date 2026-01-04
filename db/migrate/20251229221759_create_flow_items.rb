class CreateFlowItems < ActiveRecord::Migration[7.2]
  def change
    create_table :flow_items do |t|
      t.references :category, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true

      t.string  :key,  null: false
      t.string  :name, null: false
      t.string  :kana, null: false
      t.string  :icon, null: false
      t.string  :color

      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :flow_items, [ :category_id, :user_id, :key ], unique: true
  end
end
