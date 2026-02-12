class DropPostsAndCategories < ActiveRecord::Migration[7.2]
  def change
    drop_table :posts, if_exists: true
    drop_table :categories, if_exists: true
  end
end
