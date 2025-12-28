class CategoryFlowsController < ApplicationController
  def show
    @category = { title: "体調" } # 仮データ
    @items = flow_items || []
  end

  private

  def flow_items
    {
      1 => [
        { name: "暑い", kana: "あつい", icon: "Web_sunny"},
        { name: "寒い", kana: "さむい", icon: "ac_unit" },
        { name: "痛い", kana: "いたい", icon: "sick" }
      ],
      2 => [
        { name: "うれしい", kana: "うれしい", icon: "sentiment_satisfied" },
        { name: "かなしい", kana: "かなしい", icon: "sentiment_dissatisfied" }
      ]
    }[params[:id].to_i]
  end
end
