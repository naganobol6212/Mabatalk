request = MessageCategory.find_by!(key: "request")

request.flow_items.find_or_create_by!(key: "toilet") do |f|
  f.name       = "トイレ"
  f.kana       = "といれ"
  f.icon       = "wc"
  f.icon_color = "text-cyan-600"
  f.position   = 1
end

request.flow_items.find_or_create_by!(key: "temperature") do |f|
  f.name       = "温度"
  f.kana       = "おんど"
  f.icon       = "thermostat"
  f.icon_color = "text-emerald-600"
  f.position   = 2
end

request.flow_items.find_or_create_by!(key: "light") do |f|
  f.name       = "明かり"
  f.kana       = "あかり"
  f.icon       = "lightbulb"
  f.icon_color = "text-amber-500"
  f.position   = 3
end

request.flow_items.find_or_create_by!(key: "bed") do |f|
  f.name       = "ベッド"
  f.kana       = "べっど"
  f.icon       = "bed"
  f.icon_color = "text-indigo-500"
  f.position   = 4
end
