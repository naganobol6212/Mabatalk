class CreateMessageCategories < ActiveRecord::Migration[7.2]
  def change
    create_table :message_categories do |t|
      t.string :name, null: false
      t.string :kana, null: false
      t.string :icon, null: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
