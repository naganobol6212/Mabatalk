feeling = MessageCategory.find_by!(key: "feeling")

feeling.flow_items.find_or_create_by!(key: "happy") do |f|
  f.name       = "うれしい"
  f.kana       = "うれしい"
  f.icon       = "sentiment_excited"
  f.icon_color = "text-amber-500"
  f.position   = 1
end

feeling.flow_items.find_or_create_by!(key: "lonely") do |f|
  f.name       = "さみしい"
  f.kana       = "さみしい"
  f.icon       = "sentiment_dissatisfied"
  f.icon_color = "text-blue-400"
  f.position   = 2
end

feeling.flow_items.find_or_create_by!(key: "anxious") do |f|
  f.name       = "不安"
  f.kana       = "ふあん"
  f.icon       = "sentiment_worried"
  f.icon_color = "text-purple-500"
  f.position   = 3
end

feeling.flow_items.find_or_create_by!(key: "okay") do |f|
  f.name       = "大丈夫"
  f.kana       = "だいじょうぶ"
  f.icon       = "thumb_up"
  f.icon_color = "text-emerald-500"
  f.position   = 4
end
