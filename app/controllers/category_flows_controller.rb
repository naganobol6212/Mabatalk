class CategoryFlowsController < ApplicationController
  def show
    cid  = params[:category_id].to_i
    data = category_flow_data[cid] || { title: "不明", items: [] }

    @category = { title: data[:title] }
    @items    = data[:items]

    # 追加：クエリ item=hot が来たら、該当 item を特定する
    selected_key = params[:item].presence
    @selected_item = @items.find { |item| item[:key] == selected_key }
  end

  private

  def category_flow_data
    {
      1 => {
        title: "体調",
        items: [
          { key: "hot",  name: "暑い", kana: "あつい", icon: "wb_sunny" },
          { key: "cold", name: "寒い", kana: "さむい", icon: "ac_unit" }
        ]
      },
      2 => {
        title: "気持ち",
        items: [
          { key: "happy", name: "うれしい", kana: "うれしい", icon: "sentiment_satisfied" },
          { key: "sad",   name: "かなしい", kana: "かなしい", icon: "sentiment_dissatisfied" }
        ]
      }
    }
  end
end
