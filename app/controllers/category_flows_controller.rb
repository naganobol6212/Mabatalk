class CategoryFlowsController < ApplicationController
  def show
    cid  = params[:category_id].to_i
    data = category_flow_data[cid] || default_flow_data

    @category = { title: data[:title] }
    @items    = data[:items]

    # クエリ (?item=hot) で選択された項目を特定
    selected_key = params[:item].presence
    @selected_item = @items.find { |item| item[:key] == selected_key }
  end

  private

  # --- フロー定義（仮：後で DB / 定数 に移行想定） ---
  def category_flow_data
    {
      2 => {
        title: "体調",
        items: [
          { key: "hot",    name: "暑い",   kana: "あつい",   icon: "wb_sunny", color: "text-orange-500" },
          { key: "cold",   name: "寒い",   kana: "さむい",   icon: "ac_unit", color: "text-sky-500" },
          { key: "pain",   name: "痛い",   kana: "いたい",   icon: "sick", color: "text-rose-500" },
          { key: "hard",   name: "苦しい", kana: "くるしい", icon: "sentiment_very_dissatisfied", color: "text-purple-500" },
          { key: "itch",   name: "かゆい", kana: "かゆい",   icon: "pan_tool", color: "text-amber-600" },
          { key: "sleepy", name: "眠い",   kana: "ねむい",   icon: "bedtime", color: "text-indigo-400" }
        ]
      },
      3 => {
        title: "気持ち",
        items: [
          { key: "happy",   name: "うれしい", kana: "うれしい", icon: "sentiment_satisfied", color: "text-emerald-500" },
          { key: "sad",     name: "かなしい", kana: "かなしい", icon: "sentiment_dissatisfied", color: "text-sky-600" },
          { key: "angry",   name: "怒ってる", kana: "おこってる", icon: "sentiment_angry", color: "text-rose-500" },
          { key: "anxious", name: "不安",     kana: "ふあん", icon: "sentiment_stressed", color: "text-purple-500" }
        ]
      }
    }
  end

  # --- 想定外の category_id が来たとき用 ---
  def default_flow_data
    {
      title: "不明",
      items: []
    }
  end
end
