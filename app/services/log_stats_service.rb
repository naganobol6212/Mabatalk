class LogStatsService
  def self.call(user:, month:)
    new(user:, month:).call
  end

  def initialize(user:, month:)
    @user  = user
    @month = month.to_date.beginning_of_month
  end

  def call
    logs = MessageLog
      .for_viewer(@user)
      .where(created_at: @month..@month.end_of_month)

    return { chart_data: [], detail_data: {} } if logs.none?

    detail_data = build_detail_data(logs)
    { chart_data: build_chart_data(detail_data), detail_data: }
  end

  private

  def build_detail_data(logs)
    result = {}

    logs.each do |log|
      category = log.message_category_name || ""
      item     = log.flow_item_name        || ""
      color    = log.message_category_icon_color.presence || "gray"
      detail   = log.detail_flow_text.to_s.strip

      result[category]              ||= { total: 0, color:, items: {} }
      result[category][:total]       += 1
      result[category][:items][item] ||= { total: 0, details: {} }
      result[category][:items][item][:total] += 1

      next if detail.blank?

      result[category][:items][item][:details][detail] ||= 0
      result[category][:items][item][:details][detail]  += 1
    end

    # カテゴリ内の item を件数降順にソート
    result.transform_values do |cat|
      cat.merge(items: cat[:items].sort_by { |_, v| -v[:total] }.to_h)
    end
  end

  def build_chart_data(detail_data)
    # カテゴリを総件数降順でソートし、その中で item を件数降順に展開
    detail_data
      .sort_by { |_, cat| -cat[:total] }
      .flat_map do |category, cat|
        cat[:items].map do |item, item_data|
          { label: "#{category} / #{item}", count: item_data[:total], color: cat[:color] }
        end
      end
  end
end
