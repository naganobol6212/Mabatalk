class CategoryFlowsController < ApplicationController
  def show
    cid = params[:category_id].to_i
    data = category_flow_data[cid] || { title: "不明", items: [] }

    @category = { title: data[:title] }
    @items    = data[:items]
  end

  private

  def category_flow_data
    {
      1 => {
        title: "体調",
        items: [
          { name: "暑い", kana: "あつい", icon: "wb_sunny" },
          { name: "寒い", kana: "さむい", icon: "ac_unit" }
        ]
      },
      2 => {
        title: "気持ち",
        items: [
          { name: "うれしい", kana: "うれしい", icon: "sentiment_satisfied" },
          { name: "かなしい", kana: "かなしい", icon: "sentiment_dissatisfied" }
        ]
      }
    }
  end
end
