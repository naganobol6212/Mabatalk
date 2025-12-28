class CategoriesController < ApplicationController
  def index
    if current_user
      @categories = default_categories # 将来DB化後にcurrent_user.categoriesに
    else
      @categories = default_categories
    end
  end

  private

  def default_categories
    [
      { icon: "local_cafe", title: "飲みもの", ruby: "のみもの", color: "text-amber-700" },
      { icon: "accessibility_new", title: "体調", ruby: "からだのちょうし", color: "text-sky-600" },
      { icon: "sentiment_satisfied_alt", title: "気持ち", ruby: "いまのきもち", color: "text-rose-500" },
      { icon: "volunteer_activism", title: "お願い", ruby: "やってほしいこと", color: "text-emerald-600" }
    ]
  end
end
