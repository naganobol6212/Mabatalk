class CreateFeedbacks < ActiveRecord::Migration[7.2]
  def change
    create_table :feedbacks do |t|
      t.references :user, foreign_key: true, null: true
      t.integer :category, null: false, default: 0
      t.text :body, null: false

      t.timestamps
    end
  end
end
