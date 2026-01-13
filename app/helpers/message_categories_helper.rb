module MessageCategoriesHelper
  def message_category_icons
    {
      "local_cafe" => "飲みもの",
      "accessibility_new" => "体調",
      "sentiment_satisfied_alt" => "気持ち",
      "volunteer_activism" => "お願い"
    }
  end

  def icon_color(icon)
    {
      "local_cafe" => "text-orange-500",
      "accessibility_new" => "text-sky-500",
      "sentiment_satisfied_alt" => "text-rose-400",
      "volunteer_activism" => "text-emerald-500"
    }[icon] || "text-gray-400"
  end

end
