module MessageCategoriesHelper
  def message_category_icons
    IconDefinitions::CATEGORY_ICONS.transform_values { |v| v[:label] }
  end
end
