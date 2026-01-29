body = MessageCategory.find_by!(key: "body")

body.flow_items.find_or_create_by!(key: "hard") do |f|
  f.name    = "苦しい"
  f.kana     = "くるしい"
  f.icon     = "sick"
  f.icon_color    = "text-purple-500"
  f.position = 1
end

body.flow_items.find_or_create_by!(key: "pain") do |f|
  f.name    = "痛い"
  f.kana     = "いたい"
  f.icon     = "sentiment_very_dissatisfied"
  f.icon_color    = "text-red-600"
  f.position = 2
end

body.flow_items.find_or_create_by!(key: "hot") do |f|
  f.name    = "暑い"
  f.kana     = "あつい"
  f.icon     = "wb_sunny"
  f.icon_color    = "text-orange-500"
  f.position = 3
end

body.flow_items.find_or_create_by!(key: "cold") do |f|
  f.name    = "寒い"
  f.kana     = "さむい"
  f.icon     = "ac_unit"
  f.icon_color    = "text-cyan-600"
  f.position = 4
end
