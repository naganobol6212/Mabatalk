# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
# =========================
# Categories
# =========================

drink = Category.find_or_create_by!(key: "drink") do |c|
  c.title    = "飲みもの"
  c.ruby     = "のみもの"
  c.icon     = "local_cafe"
  c.color    = "text-amber-700"
  c.position = 1
end

body = Category.find_or_create_by!(key: "body") do |c|
  c.title    = "体調"
  c.ruby     = "からだのちょうし"
  c.icon     = "accessibility_new"
  c.color    = "text-sky-600"
  c.position = 2
end

feeling = Category.find_or_create_by!(key: "feeling") do |c|
  c.title    = "気持ち"
  c.ruby     = "いまのきもち"
  c.icon     = "sentiment_satisfied_alt"
  c.color    = "text-rose-500"
  c.position = 3
end

request = Category.find_or_create_by!(key: "request") do |c|
  c.title    = "お願い"
  c.ruby     = "やってほしいこと"
  c.icon     = "volunteer_activism"
  c.color    = "text-emerald-600"
  c.position = 4
end

# =========================
# FlowItems - Drink
# =========================

drink.flow_items.find_or_create_by!(key: "water") do |f|
  f.name     = "水"
  f.kana     = "みず"
  f.icon     = "water_drop"
  f.color    = "text-cyan-500"
  f.position = 1
end

drink.flow_items.find_or_create_by!(key: "tea") do |f|
  f.name     = "お茶"
  f.kana     = "おちゃ"
  f.icon     = "emoji_food_beverage"
  f.color    = "text-green-600"
  f.position = 2
end

drink.flow_items.find_or_create_by!(key: "cola") do |f|
  f.name     = "コーラ"
  f.kana     = "こーら"
  f.icon     = "local_drink"
  f.color    = "text-rose-700"
  f.position = 3
end

drink.flow_items.find_or_create_by!(key: "sports_drink") do |f|
  f.name     = "ポカリ"
  f.kana     = "ぽかり"
  f.icon     = "water"
  f.color    = "text-blue-500"
  f.position = 4
end

drink.flow_items.find_or_create_by!(key: "coffee") do |f|
  f.name     = "コーヒー"
  f.kana     = "こーひー"
  f.icon     = "coffee"
  f.color    = "text-amber-800"
  f.position = 5
end

drink.flow_items.find_or_create_by!(key: "fruit_juice") do |f|
  f.name     = "フルーツジュース"
  f.kana     = "ふるーつじゅーす"
  f.icon     = "local_bar"
  f.color    = "text-orange-500"
  f.position = 6
end

# =========================
# FlowItems - Body
# =========================

body.flow_items.find_or_create_by!(key: "hot") do |f|
  f.name     = "暑い"
  f.kana     = "あつい"
  f.icon     = "wb_sunny"
  f.color    = "text-orange-500"
  f.position = 1
end

body.flow_items.find_or_create_by!(key: "cold") do |f|
  f.name     = "寒い"
  f.kana     = "さむい"
  f.icon     = "ac_unit"
  f.color    = "text-sky-500"
  f.position = 2
end

body.flow_items.find_or_create_by!(key: "pain") do |f|
  f.name     = "痛い"
  f.kana     = "いたい"
  f.icon     = "sick"
  f.color    = "text-rose-500"
  f.position = 3
end

body.flow_items.find_or_create_by!(key: "hard") do |f|
  f.name     = "苦しい"
  f.kana     = "くるしい"
  f.icon     = "sentiment_very_dissatisfied"
  f.color    = "text-purple-500"
  f.position = 4
end

body.flow_items.find_or_create_by!(key: "itch") do |f|
  f.name     = "かゆい"
  f.kana     = "かゆい"
  f.icon     = "pan_tool"
  f.color    = "text-amber-600"
  f.position = 5
end

body.flow_items.find_or_create_by!(key: "sleep") do |f|
  f.name     = "眠い"
  f.kana     = "ねむい"
  f.icon     = "bedtime"
  f.color    = "text-indigo-400"
  f.position = 6
end

# =========================
# FlowItems - Feeling
# =========================

feeling.flow_items.find_or_create_by!(key: "thanks") do |f|
  f.name     = "ありがとう"
  f.kana     = "ありがとう"
  f.icon     = "favorite"
  f.color    = "text-pink-500"
  f.position = 1
end

feeling.flow_items.find_or_create_by!(key: "happy") do |f|
  f.name     = "うれしい"
  f.kana     = "うれしい"
  f.icon     = "sentiment_very_satisfied"
  f.color    = "text-amber-500"
  f.position = 2
end

feeling.flow_items.find_or_create_by!(key: "lonely") do |f|
  f.name     = "さみしい"
  f.kana     = "さみしい"
  f.icon     = "sentiment_dissatisfied"
  f.color    = "text-blue-400"
  f.position = 3
end

feeling.flow_items.find_or_create_by!(key: "anxious") do |f|
  f.name     = "不安"
  f.kana     = "ふあん"
  f.icon     = "help"
  f.color    = "text-purple-500"
  f.position = 4
end

feeling.flow_items.find_or_create_by!(key: "okay") do |f|
  f.name     = "大丈夫"
  f.kana     = "だいじょうぶ"
  f.icon     = "thumb_up"
  f.color    = "text-emerald-500"
  f.position = 5
end

# =========================
# FlowItems - Request
# =========================

request.flow_items.find_or_create_by!(key: "temperature") do |f|
  f.name     = "温度"
  f.kana     = "おんど"
  f.icon     = "thermostat"
  f.color    = "text-red-500"
  f.position = 1
end

request.flow_items.find_or_create_by!(key: "bed") do |f|
  f.name     = "ベッド"
  f.kana     = "べっど"
  f.icon     = "bed"
  f.color    = "text-blue-500"
  f.position = 2
end

request.flow_items.find_or_create_by!(key: "light") do |f|
  f.name     = "明かり"
  f.kana     = "あかり"
  f.icon     = "lightbulb"
  f.color    = "text-amber-500"
  f.position = 3
end

request.flow_items.find_or_create_by!(key: "curtain") do |f|
  f.name     = "カーテン"
  f.kana     = "かーてん"
  f.icon     = "curtains"
  f.color    = "text-emerald-500"
  f.position = 4
end

request.flow_items.find_or_create_by!(key: "tv") do |f|
  f.name     = "テレビ"
  f.kana     = "てれび"
  f.icon     = "tv"
  f.color    = "text-indigo-500"
  f.position = 5
end

request.flow_items.find_or_create_by!(key: "toilet") do |f|
  f.name     = "トイレ"
  f.kana     = "といれ"
  f.icon     = "wc"
  f.color    = "text-cyan-600"
  f.position = 6
end
