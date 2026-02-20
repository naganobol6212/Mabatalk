module MessageCategoriesHelper
  def message_category_icons
    IconDefinitions::CATEGORY_ICONS.transform_values { |v| v[:label] }
  end

  def icon_color(icon)
    IconDefinitions::CATEGORY_ICONS.dig(icon, :color) || "text-gray-400"
  end
end
