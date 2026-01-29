body = MessageCategory.find_by!(key: "body")

items = [
  {
    key: "hard",
    name: "苦しい",
    kana: "くるしい",
    icon: "sick",
    icon_color: "text-purple-500",
    position: 1
  },
  {
    key: "pain",
    name: "痛い",
    kana: "いたい",
    icon: "sentiment_very_dissatisfied",
    icon_color: "text-red-600",
    position: 2
  },
  {
    key: "hot",
    name: "暑い",
    kana: "あつい",
    icon: "wb_sunny",
    icon_color: "text-orange-500",
    position: 3
  },
  {
    key: "cold",
    name: "寒い",
    kana: "さむい",
    icon: "ac_unit",
    icon_color: "text-cyan-600",
    position: 4
  }
]

items.each do |attrs|
  item = body.flow_items.find_or_initialize_by(key: attrs[:key])
  item.assign_attributes(attrs)
  item.save!
end
