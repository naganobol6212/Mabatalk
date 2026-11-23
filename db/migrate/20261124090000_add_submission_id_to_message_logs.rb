class AddSubmissionIdToMessageLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :message_logs, :submission_id, :string
    add_index :message_logs, [ :user_id, :submission_id ], unique: true
  end
end
