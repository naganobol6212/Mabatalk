request = MessageCategory.find_by!(key: "request")

items = [
  {
    key: "toilet",
    name: "トイレ",
    kana: "といれ",
    icon: "wc",
    icon_color: "text-cyan-600",
    position: 1
  },
  {
    key: "temperature",
    name: "温度",
    kana: "おんど",
    icon: "thermostat",
    icon_color: "text-emerald-500",
    position: 2
  },
  {
    key: "light",
    name: "明かり",
    kana: "あかり",
    icon: "lightbulb",
    icon_color: "text-amber-500",
    position: 3
  },
  {
    key: "bed",
    name: "ベッド",
    kana: "べっど",
    icon: "bed",
    icon_color: "text-indigo-500",
    position: 4
  }
]

items.each do |attrs|
  item = FlowItem.find_or_initialize_by(key: attrs[:key], user_id: nil)
  item.assign_attributes(attrs.merge(
    user_id: nil,
    message_category: request
  ))
  item.save!
end
