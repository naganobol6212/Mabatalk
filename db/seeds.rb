# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
FlowItem.destroy_all
Category.destroy_all

Category.create!([
  {
    title: "飲みもの",
    ruby: "のみもの",
    icon: "local_cafe",
    color: "text-amber-700",
    position: 1
  },
  {
    title: "体調",
    ruby: "からだのちょうし",
    icon: "accessibility_new",
    color: "text-sky-600",
    position: 2
  },
  {
    title: "気持ち",
    ruby: "いまのきもち",
    icon: "sentiment_satisfied_alt",
    color: "text-rose-500",
    position: 3
  },
  {
    title: "お願い",
    ruby: "やってほしいこと",
    icon: "volunteer_activism",
    color: "text-emerald-600",
    position: 4
  }
])
drink = Category.find_by!(title: "飲みもの")

drink.flow_items.create!([
  {
    key: "water",
    name: "水",
    kana: "みず",
    icon: "water_drop",
    color: "text-cyan-500",
    position: 1
  },
  {
    key: "tea",
    name: "お茶",
    kana: "おちゃ",
    icon: "emoji_food_beverage",
    color: "text-green-600",
    position: 2
  },
  {
    key: "cola",
    name: "コーラ",
    kana: "こーら",
    icon: "local_drink",
    color: "text-rose-700",
    position: 3
  },
  {
    key: "sports_drink",
    name: "ポカリ",
    kana: "ぽかり",
    icon: "water",
    color: "text-blue-500",
    position: 4
  },
  {
    key: "coffee",
    name: "コーヒー",
    kana: "こーひー",
    icon: "coffee",
    color: "text-amber-800",
    position: 5
  },
  {
    key: "fruit_juice",
    name: "フルーツジュース",
    kana: "ふるーつじゅーす",
    icon: "local_bar",
    color: "text-orange-500",
    position: 6
  }
])

body = Category.find_by!(title: "体調")

body.flow_items.create!([
  {
    key: "hot",
    name: "暑い",
    kana: "あつい",
    icon: "wb_sunny",
    color: "text-orange-500",
    position: 1
  },
  {
    key: "cold",
    name: "寒い",
    kana: "さむい",
    icon: "ac_unit",
    color: "text-sky-500",
    position: 2
  },
  {
    key: "pain",
    name: "痛い",
    kana: "いたい",
    icon: "sick",
    color: "text-rose-500",
    position: 3
  },
  {
    key: "hard",
    name: "苦しい",
    kana: "くるしい",
    icon: "sentiment_very_dissatisfied",
    color: "text-purple-500",
    position: 4
  },
  {
    key: "itch",
    name: "かゆい",
    kana: "かゆい",
    icon: "pan_tool",
    color: "text-amber-600",
    position: 5
  },
  {
    key: "sleep",
    name: "眠い",
    kana: "ねむい",
    icon: "bedtime",
    color: "text-indigo-400",
    position: 6
  }
])
feeling = Category.find_by!(title: "気持ち")

feeling.flow_items.create!([
  {
    key: "thanks",
    name: "ありがとう",
    kana: "ありがとう",
    icon: "favorite",
    color: "text-pink-500",
    position: 1
  },
  {
    key: "happy",
    name: "うれしい",
    kana: "うれしい",
    icon: "sentiment_very_satisfied",
    color: "text-amber-500",
    position: 2
  },
  {
    key: "lonely",
    name: "さみしい",
    kana: "さみしい",
    icon: "sentiment_dissatisfied",
    color: "text-blue-400",
    position: 3
  },
  {
    key: "anxious",
    name: "不安",
    kana: "ふあん",
    icon: "help",
    color: "text-purple-500",
    position: 4
  },
  {
    key: "okay",
    name: "大丈夫",
    kana: "だいじょうぶ",
    icon: "thumb_up",
    color: "text-emerald-500",
    position: 5
  }
])
request = Category.find_by!(title: "お願い")

request.flow_items.create!([
  {
    key: "temperature",
    name: "温度",
    kana: "おんど",
    icon: "thermostat",
    color: "text-red-500",
    position: 1
  },
  {
    key: "bed",
    name: "ベッド",
    kana: "べっど",
    icon: "bed",
    color: "text-blue-500",
    position: 2
  },
  {
    key: "light",
    name: "明かり",
    kana: "あかり",
    icon: "lightbulb",
    color: "text-amber-500",
    position: 3
  },
  {
    key: "curtain",
    name: "カーテン",
    kana: "かーてん",
    icon: "curtains",
    color: "text-emerald-500",
    position: 4
  },
  {
    key: "tv",
    name: "テレビ",
    kana: "てれび",
    icon: "tv",
    color: "text-indigo-500",
    position: 5
  },
  {
    key: "toilet",
    name: "トイレ",
    kana: "といれ",
    icon: "wc",
    color: "text-cyan-600",
    position: 6
  }
])
