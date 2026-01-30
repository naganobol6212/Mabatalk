drink = MessageCategory.find_by!(key: "drink")

items = [
  {
    key: "water",
    name: "水",
    kana: "みず",
    icon: "water_drop",
    icon_color: "text-cyan-500",
    position: 1
  },
  {
    key: "sports_drink",
    name: "スポーツドリンク",
    kana: "すぽーつどりんく",
    icon: "water",
    icon_color: "text-blue-600",
    position: 2
  },
  {
    key: "tea",
    name: "お茶",
    kana: "おちゃ",
    icon: "emoji_food_beverage",
    icon_color: "text-green-600",
    position: 3
  },
  {
    key: "carbonated_drink",
    name: "炭酸飲料",
    kana: "たんさんいんりょう",
    icon: "local_drink",
    icon_color: "text-yellow-500",
    position: 4
  },
  {
    key: "fruit_juice",
    name: "フルーツジュース",
    kana: "ふるーつじゅーす",
    icon: "grocery",
    icon_color: "text-orange-500",
    position: 5
  }
]

items.each do |attrs|
  item = FlowItem.find_or_initialize_by(key: attrs[:key], user_id: nil)
  item.assign_attributes(attrs.merge(
    user_id: nil,
    message_category: drink
  ))
  item.save!
end
