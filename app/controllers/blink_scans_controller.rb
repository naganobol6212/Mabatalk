# まばたきスキャン画面。1 つのカテゴリの定型文を順に光らせて選ぶ。
# ゲストも使える（authenticate_user! を付けない）。ゲストは共有のカテゴリ・共有の定型文だけ。
class BlinkScansController < ApplicationController
  # 定型文がこの数を超えたら、介助者に「絞る・分ける」ことをすすめる
  ITEM_NOTICE_THRESHOLD = 10

  def show
    @message_category = MessageCategory.for_user(current_user).find(params[:message_category_id])
    # スキャンの順番がぶれないよう、同じ position の時は id の順に固定する
    @flow_items = @message_category.flow_items.for_user(current_user).order(:position, :id).load
    @too_many_items = @flow_items.size > ITEM_NOTICE_THRESHOLD

    # 出た先の画面（GA がある）に「前にいたページ」としてこの URL を渡さない・ブラウザに残さない
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Cache-Control"] = "no-store"
  end
end
