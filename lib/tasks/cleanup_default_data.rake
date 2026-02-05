namespace :data do
  desc "Remove invalid default MessageCategory / FlowItem (user_id = nil)"
  task cleanup_defaults: :environment do
    puts "== Cleanup default MessageCategory =="

    valid_category_keys = %w[body drink request feeling]

    deleted_categories = MessageCategory
      .where(user_id: nil)
      .where.not(key: valid_category_keys)
      .delete_all

    puts "Deleted MessageCategory: #{deleted_categories}"

    puts "== Cleanup default FlowItem =="

    valid_flow_item_keys = %w[
      hard pain hot cold
      water sports_drink tea carbonated_drink fruit_juice
      happy lonely anxious okay
      toilet temperature light bed
    ]

    deleted_items = FlowItem
      .where(user_id: nil)
      .where.not(key: valid_flow_item_keys)
      .delete_all

    puts "Deleted FlowItem: #{deleted_items}"

    puts "DONE."
  end
end
