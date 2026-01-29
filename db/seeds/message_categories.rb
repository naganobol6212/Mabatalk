MessageCategory.find_or_create_by!(key: "body") do |c|
  c.name    = "体調"
  c.kana     = "からだのちょうし"
  c.icon     = "accessibility_new"
  c.icon_color    = "text-orange-600"
  c.position = 1
end

MessageCategory.find_or_create_by!(key: "drink") do |c|
  c.name    = "飲みもの"
  c.kana     = "のみもの"
  c.icon     = "local_drink"
  c.icon_color    = "text-sky-600"
  c.position = 2
end

MessageCategory.find_or_create_by!(key: "request") do |c|
  c.name    = "お願い"
  c.kana     = "やってほしいこと"
  c.icon     = "volunteer_activism"
  c.icon_color    = "text-emerald-600"
  c.position = 3
end

MessageCategory.find_or_create_by!(key: "feeling") do |c|
  c.name    = "気持ち"
  c.kana     = "いまのきもち"
  c.icon     = "sentiment_satisfied_alt"
  c.icon_color    = "text-rose-500"
  c.position = 4
end
