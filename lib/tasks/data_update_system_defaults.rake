namespace :data do
  desc "Update system(default) MessageCategory and FlowItem to match seeds definition"
  task update_system_defaults: :environment do
    ActiveRecord::Base.transaction do
      puts "== Update system MessageCategory =="

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
        category = MessageCategory.find_by!(key: attrs[:key], user_id: nil)
        category.update!(attrs)
        puts "Updated MessageCategory: #{attrs[:key]}"
      end

      puts "== Update system FlowItem =="

      flow_item_seeds = {
        # body
        "hard" => {
          category: "body",
          name: "苦しい",
          kana: "くるしい",
          icon: "sick",
          icon_color: "text-purple-500",
          position: 1
        },
        "pain" => {
          category: "body",
          name: "痛い",
          kana: "いたい",
          icon: "sentiment_very_dissatisfied",
          icon_color: "text-red-600",
          position: 2
        },
        "hot" => {
          category: "body",
          name: "暑い",
          kana: "あつい",
          icon: "wb_sunny",
          icon_color: "text-orange-500",
          position: 3
        },
        "cold" => {
          category: "body",
          name: "寒い",
          kana: "さむい",
          icon: "ac_unit",
          icon_color: "text-cyan-600",
          position: 4
        },

        # drink
        "water" => {
          category: "drink",
          name: "水",
          kana: "みず",
          icon: "water_drop",
          icon_color: "text-cyan-500",
          position: 1
        },
        "sports_drink" => {
          category: "drink",
          name: "スポーツドリンク",
          kana: "すぽーつどりんく",
          icon: "water",
          icon_color: "text-blue-600",
          position: 2
        },
        "tea" => {
          category: "drink",
          name: "お茶",
          kana: "おちゃ",
          icon: "emoji_food_beverage",
          icon_color: "text-green-600",
          position: 3
        },
        "carbonated_drink" => {
          category: "drink",
          name: "炭酸飲料",
          kana: "たんさんいんりょう",
          icon: "local_drink",
          icon_color: "text-yellow-500",
          position: 4
        },
        "fruit_juice" => {
          category: "drink",
          name: "フルーツジュース",
          kana: "ふるーつじゅーす",
          icon: "grocery",
          icon_color: "text-orange-500",
          position: 5
        },

        # feeling
        "happy" => {
          category: "feeling",
          name: "うれしい",
          kana: "うれしい",
          icon: "sentiment_excited",
          icon_color: "text-amber-500",
          position: 1
        },
        "lonely" => {
          category: "feeling",
          name: "さみしい",
          kana: "さみしい",
          icon: "sentiment_dissatisfied",
          icon_color: "text-blue-400",
          position: 2
        },
        "anxious" => {
          category: "feeling",
          name: "不安",
          kana: "ふあん",
          icon: "sentiment_worried",
          icon_color: "text-purple-500",
          position: 3
        },
        "okay" => {
          category: "feeling",
          name: "大丈夫",
          kana: "だいじょうぶ",
          icon: "thumb_up",
          icon_color: "text-emerald-500",
          position: 4
        },

        # request
        "toilet" => {
          category: "request",
          name: "トイレ",
          kana: "といれ",
          icon: "wc",
          icon_color: "text-cyan-600",
          position: 1
        },
        "temperature" => {
          category: "request",
          name: "温度",
          kana: "おんど",
          icon: "thermostat",
          icon_color: "text-emerald-500",
          position: 2
        },
        "light" => {
          category: "request",
          name: "明かり",
          kana: "あかり",
          icon: "lightbulb",
          icon_color: "text-amber-500",
          position: 3
        },
        "bed" => {
          category: "request",
          name: "ベッド",
          kana: "べっど",
          icon: "bed",
          icon_color: "text-indigo-500",
          position: 4
        }
      }

      FlowItem.where(user_id: nil).find_each do |item|
        seed = flow_item_seeds[item.key]
        next unless seed

        category = MessageCategory.find_by!(key: seed[:category], user_id: nil)

        item.update!(
          name: seed[:name],
          kana: seed[:kana],
          icon: seed[:icon],
          icon_color: seed[:icon_color],
          position: seed[:position],
          message_category: category
        )

        puts "Updated FlowItem: #{item.key}"
      end

      puts "DONE: system defaults updated successfully"
    end
  end
end
