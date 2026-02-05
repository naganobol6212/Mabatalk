namespace :data do
  desc "Normalize positions and icon_color for MessageCategory / FlowItem"
  task normalize_positions: :environment do
    ActiveRecord::Base.transaction do
      puts "== Normalize MessageCategory positions =="

      default_order = %w[body drink request feeling]

      default_order.each_with_index do |key, idx|
        cat = MessageCategory.find_by(user_id: nil, key: key)
        next unless cat

        desired = idx + 1
        next if cat.position == desired

        cat.update_columns(position: desired, updated_at: Time.current)
      end

      MessageCategory
        .where.not(user_id: nil)
        .select(:user_id)
        .distinct
        .pluck(:user_id)
        .each do |uid|
          MessageCategory
            .where(user_id: uid)
            .order(:created_at, :id)
            .each_with_index do |cat, idx|
              desired = idx + 1
              next if cat.position == desired

              cat.update_columns(position: desired, updated_at: Time.current)
            end
        end

      puts "== Normalize FlowItem positions & icon_color =="

      default_color = "text-slate-600"

      MessageCategory
        .where(user_id: nil)
        .find_each do |cat|

          cat.flow_items
              .order(:position, :created_at, :id)
              .each_with_index do |item, idx|

            desired_pos   = idx + 1
            desired_color = item.icon_color.presence || default_color

            updates = {}
            updates[:position]   = desired_pos   if item.position != desired_pos
            updates[:icon_color] = desired_color if item.icon_color != desired_color

            next if updates.empty?

            item.update_columns(updates.merge(updated_at: Time.current))
          end
        end

      MessageCategory
        .where.not(user_id: nil)
        .select(:user_id)
        .distinct
        .pluck(:user_id)
        .each do |uid|

          MessageCategory
            .where(user_id: uid)
            .find_each do |cat|

              cat.flow_items
                  .order(:position, :created_at, :id)
                  .each_with_index do |item, idx|

                desired_pos   = idx + 1
                desired_color = item.icon_color.presence || default_color

                updates = {}
                updates[:position]   = desired_pos   if item.position != desired_pos
                updates[:icon_color] = desired_color if item.icon_color != desired_color

                next if updates.empty?

                item.update_columns(updates.merge(updated_at: Time.current))
              end
            end
        end

      puts "DONE."
    end
  end
end