module ApplicationHelper
  def icon_colors
    IconDefinitions::ICON_COLORS
  end
  # semantic key（"orange" 等）→ Tailwind テキストカラークラスに変換する
  # 旧設計で "text-orange-500" 等が保存されていた場合はそのまま通す（後方互換）
  def icon_color_class(key)
    return key if key&.start_with?("text-")
    IconDefinitions::ICON_COLORS.dig(key, :text) || "text-gray-400"
  end
  # semantic key（"orange" 等）→ Tailwind 背景カラークラスに変換する（スウォッチ用）
  def icon_bg_class(key)
    IconDefinitions::ICON_COLORS.dig(key, :bg) || "bg-gray-400"
  end

  def login_features
    [
      { icon: "edit_note",    title: "カテゴリ/項目をカスタマイズ",     description: "ご本人にあわせて、使いやすいように項目を自由に追加・調整できます。" },
      { icon: "insights",     title: "履歴をグラフで可視化",             description: "メッセージの選択結果が自動で蓄積され、日々の変化をグラフで振り返れます。" },
      { icon: "auto_awesome", title: "AIがメッセージの傾向を振り返り",   description: "履歴に保存された項目をAIがまとめて、振り返りコメントを届けます。" }
    ]
  end
end
