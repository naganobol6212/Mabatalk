class AddKeyToFeedbacks < ActiveRecord::Migration[7.2]
  def up
    add_column :feedbacks, :key, :string

    Feedback.reset_column_information
    Feedback.find_each do |feedback|
      feedback.update_column(:key, SecureRandom.uuid)
    end

    change_column_null :feedbacks, :key, false
    add_index :feedbacks, :key, unique: true
  end

  def down
    remove_index :feedbacks, :key
    remove_column :feedbacks, :key
  end
end
