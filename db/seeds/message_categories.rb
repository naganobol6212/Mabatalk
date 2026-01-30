categories = [
  {
    key: "body",
    name: "体調",
    kana: "からだのちょうし",
    icon: "accessibility_new",
    icon_color: "text-orange-600",
    position: 1
  },
  {
    key: "drink",
    name: "飲みもの",
    kana: "のみもの",
    icon: "local_drink",
    icon_color: "text-sky-600",
    position: 2
  },
  {
    key: "request",
    name: "お願い",
    kana: "やってほしいこと",
    icon: "volunteer_activism",
    icon_color: "text-emerald-600",
    position: 3
  },
  {
    key: "feeling",
    name: "気持ち",
    kana: "いまのきもち",
    icon: "sentiment_satisfied_alt",
    icon_color: "text-rose-500",
    position: 4
  }
]

categories.each do |attrs|
  mc = MessageCategory.find_or_initialize_by(
    key: attrs[:key],
    user_id: nil
  )
  mc.assign_attributes(attrs.merge(user_id: nil))
  mc.save!
end
