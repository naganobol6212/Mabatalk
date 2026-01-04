class AddUserToCategories < ActiveRecord::Migration[7.2]
  def change
    add_reference :categories, :user, null: true, foreign_key: true
  end
end
