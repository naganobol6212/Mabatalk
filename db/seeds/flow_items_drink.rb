drink = MessageCategory.find_by!(key: "drink")

drink.flow_items.find_or_create_by!(key: "water") do |f|
  f.name       = "水"
  f.kana       = "みず"
  f.icon       = "water_drop"
  f.icon_color = "text-cyan-500"
  f.position   = 1
end

drink.flow_items.find_or_create_by!(key: "sports_drink") do |f|
  f.name       = "スポーツドリンク"
  f.kana       = "すぽーつどりんく"
  f.icon       = "water"
  f.icon_color = "text-blue-600"
  f.position   = 2
end

drink.flow_items.find_or_create_by!(key: "tea") do |f|
  f.name       = "お茶"
  f.kana       = "おちゃ"
  f.icon       = "emoji_food_beverage"
  f.icon_color = "text-green-600"
  f.position   = 3
end

drink.flow_items.find_or_create_by!(key: "carbonated_drink") do |f|
  f.name       = "炭酸飲料"
  f.kana       = "たんさんいんりょう"
  f.icon       = "local_drink"
  f.icon_color = "text-yellow-500"
  f.position   = 4
end

drink.flow_items.find_or_create_by!(key: "fruit_juice") do |f|
  f.name       = "フルーツジュース"
  f.kana       = "ふるーつじゅーす"
  f.icon       = "grocery"
  f.icon_color = "text-orange-500"
  f.position   = 5
end
