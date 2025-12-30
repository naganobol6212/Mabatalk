# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
Category.destroy_all

Category.create!([
  {
    title: "飲みもの",
    ruby: "のみもの",
    icon: "local_cafe",
    color: "text-amber-700",
    position: 1
  },
  {
    title: "体調",
    ruby: "からだのちょうし",
    icon: "accessibility_new",
    color: "text-sky-600",
    position: 2
  },
  {
    title: "気持ち",
    ruby: "いまのきもち",
    icon: "sentiment_satisfied_alt",
    color: "text-rose-500",
    position: 3
  },
  {
    title: "お願い",
    ruby: "やってほしいこと",
    icon: "volunteer_activism",
    color: "text-emerald-600",
    position: 4
  }
])

