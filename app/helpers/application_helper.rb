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
end
