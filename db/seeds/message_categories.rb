MessageCategory.find_or_create_by!(key: "body") do |c|
  c.title    = "体調"
  c.ruby     = "からだのちょうし"
  c.icon     = "accessibility_new"
  c.color    = "text-orange-600"
  c.position = 1
end

MessageCategory.find_or_create_by!(key: "drink") do |c|
  c.title    = "飲みもの"
  c.ruby     = "のみもの"
  c.icon     = "local_drink"
  c.color    = "text-sky-600"
  c.position = 2
end

MessageCategory.find_or_create_by!(key: "request") do |c|
  c.title    = "お願い"
  c.ruby     = "やってほしいこと"
  c.icon     = "volunteer_activism"
  c.color    = "text-emerald-600"
  c.position = 3
end

MessageCategory.find_or_create_by!(key: "feeling") do |c|
  c.title    = "気持ち"
  c.ruby     = "いまのきもち"
  c.icon     = "sentiment_satisfied_alt"
  c.color    = "text-rose-500"
  c.position = 4
end
