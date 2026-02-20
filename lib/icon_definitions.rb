module IconDefinitions
  # カテゴリ用アイコン定義
  # key: Material Symbols の識別名（DBに保存される値）
  # value: label（表示ラベル）, color（Tailwind カラークラス）
  # 既存アイコン名を削除すると既存DBデータが孤立するため、削除禁止。
  CATEGORY_ICONS = {
    "local_cafe"              => { label: "飲みもの", color: "text-orange-500" },
    "accessibility_new"       => { label: "体調",     color: "text-sky-500" },
    "sentiment_satisfied_alt" => { label: "気持ち",   color: "text-rose-400" },
    "volunteer_activism"      => { label: "お願い",   color: "text-emerald-500" }
  }.freeze

  # FlowItem用アイコン定義
  # 既存アイコン名を削除すると既存DBデータが孤立するため、削除禁止。
  FLOW_ITEM_ICONS = %w[
    water_drop
    local_bar
    emoji_food_beverage
    coffee
    sports_bar
    liquor
  ].freeze
end
