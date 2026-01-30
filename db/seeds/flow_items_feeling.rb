feeling = MessageCategory.find_by!(key: "feeling")

items = [
  {
    key: "happy",
    name: "うれしい",
    kana: "うれしい",
    icon: "sentiment_excited",
    icon_color: "text-amber-500",
    position: 1
  },
  {
    key: "lonely",
    name: "さみしい",
    kana: "さみしい",
    icon: "sentiment_dissatisfied",
    icon_color: "text-blue-400",
    position: 2
  },
  {
    key: "anxious",
    name: "不安",
    kana: "ふあん",
    icon: "sentiment_worried",
    icon_color: "text-purple-500",
    position: 3
  },
  {
    key: "okay",
    name: "大丈夫",
    kana: "だいじょうぶ",
    icon: "thumb_up",
    icon_color: "text-emerald-500",
    position: 4
  }
]

items.each do |attrs|
  item = FlowItem.find_or_initialize_by(key: attrs[:key], user_id: nil)
  item.assign_attributes(attrs.merge(
    user_id: nil,
    message_category: feeling
  ))
  item.save!
end
