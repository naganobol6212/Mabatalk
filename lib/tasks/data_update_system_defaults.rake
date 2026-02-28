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
          icon_color: "orange",
          position: 1
        },
        {
          key: "drink",
          name: "飲みもの",
          kana: "のみもの",
          icon: "local_drink",
          icon_color: "sky",
          position: 2
        },
        {
          key: "request",
          name: "お願い",
          kana: "やってほしいこと",
          icon: "volunteer_activism",
          icon_color: "emerald",
          position: 3
        },
        {
          key: "feeling",
          name: "気持ち",
          kana: "いまのきもち",
          icon: "sentiment_satisfied_alt",
          icon_color: "rose",
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
          icon_color: "violet",
          position: 1
        },
        "pain" => {
          category: "body",
          name: "痛い",
          kana: "いたい",
          icon: "sentiment_very_dissatisfied",
          icon_color: "red",
          position: 2,
          detail_flow_key: "pain_detail"
        },
        "itchy" => {
          category: "body",
          name: "かゆい",
          kana: "かゆい",
          icon: "sentiment_stressed",
          icon_color: "yellow",
          position: 3,
          detail_flow_key: "itch_detail"
        },
        "hot" => {
          category: "body",
          name: "暑い",
          kana: "あつい",
          icon: "wb_sunny",
          icon_color: "orange",
          position: 4,
          detail_flow_key: "hot_detail"
        },
        "cold" => {
          category: "body",
          name: "寒い",
          kana: "さむい",
          icon: "ac_unit",
          icon_color: "cyan",
          position: 5,
          detail_flow_key: "cold_detail"
        },

        # drink
        "water" => {
          category: "drink",
          name: "水",
          kana: "みず",
          icon: "water_drop",
          icon_color: "cyan",
          position: 1,
          detail_flow_key: "drink_detail"
        },
        "sports_drink" => {
          category: "drink",
          name: "スポーツドリンク",
          kana: "すぽーつどりんく",
          icon: "water",
          icon_color: "blue",
          position: 2,
          detail_flow_key: "drink_amount_detail"
        },
        "tea" => {
          category: "drink",
          name: "お茶",
          kana: "おちゃ",
          icon: "emoji_food_beverage",
          icon_color: "green",
          position: 3,
          detail_flow_key: "drink_detail"
        },
        "carbonated_drink" => {
          category: "drink",
          name: "炭酸飲料",
          kana: "たんさんいんりょう",
          icon: "local_drink",
          icon_color: "yellow",
          position: 4,
          detail_flow_key: "drink_amount_detail"
        },
        "fruit_juice" => {
          category: "drink",
          name: "フルーツジュース",
          kana: "ふるーつじゅーす",
          icon: "grocery",
          icon_color: "orange",
          position: 5,
          detail_flow_key: "drink_amount_detail"
        },

        # feeling
        "happy" => {
          category: "feeling",
          name: "うれしい",
          kana: "うれしい",
          icon: "sentiment_excited",
          icon_color: "amber",
          position: 1
        },
        "lonely" => {
          category: "feeling",
          name: "さみしい",
          kana: "さみしい",
          icon: "sentiment_dissatisfied",
          icon_color: "blue",
          position: 2
        },
        "anxious" => {
          category: "feeling",
          name: "不安",
          kana: "ふあん",
          icon: "sentiment_worried",
          icon_color: "violet",
          position: 3
        },
        "okay" => {
          category: "feeling",
          name: "大丈夫",
          kana: "だいじょうぶ",
          icon: "thumb_up",
          icon_color: "emerald",
          position: 4
        },

        # request
        "toilet" => {
          category: "request",
          name: "トイレ",
          kana: "といれ",
          icon: "wc",
          icon_color: "cyan",
          position: 1
        },
        "temperature" => {
          category: "request",
          name: "温度",
          kana: "おんど",
          icon: "thermostat",
          icon_color: "emerald",
          position: 2,
          detail_flow_key: "room_temp_detail"
        },
        "light" => {
          category: "request",
          name: "明かり",
          kana: "あかり",
          icon: "lightbulb",
          icon_color: "amber",
          position: 3,
          detail_flow_key: "light_detail"
        },
        "bed" => {
          category: "request",
          name: "ベッド",
          kana: "べっど",
          icon: "bed",
          icon_color: "indigo",
          position: 4,
          detail_flow_key: "bed_detail"
        }
      }

      FlowItem.where(user_id: nil).find_each do |item|
        seed = flow_item_seeds[item.key]
        next unless seed

        category = MessageCategory.find_by!(key: seed[:category], user_id: nil)

        item.update!(
          name:             seed[:name],
          kana:             seed[:kana],
          icon:             seed[:icon],
          icon_color:       seed[:icon_color],
          position:         seed[:position],
          message_category: category,
          detail_flow_key:  seed[:detail_flow_key]
        )

        puts "Updated FlowItem: #{item.key}"
      end

      puts "DONE: system defaults updated successfully"
    end
  end
end
