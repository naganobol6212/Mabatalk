module CategoriesHelper
  def category_color(category)
    if category.respond_to?(:color)
      category.color
    else
      icon_color(category.icon)
    end
  end
end
