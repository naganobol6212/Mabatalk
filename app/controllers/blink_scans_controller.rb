# まばたきスキャン画面。1 つのカテゴリの定型文を順に光らせて選ぶ。
# ゲストも使える（authenticate_user! を付けない）。ゲストは共有のカテゴリ・共有の定型文だけ。
class BlinkScansController < ApplicationController
  # 定型文がこの数を超えたら、介助者に「絞る・分ける」ことをすすめる
  ITEM_NOTICE_THRESHOLD = 10

  # この画面だけの CSP。今は report-only（違反をブラウザのコンソールに出すだけで、止めない）。
  # 強制に切り替えるかは、実機で違反を見てから PR3c の公開判定で決める。
  # report-only は止める設定ではないので、「外へ送らない」ことの保証にはしない。
  # Worker の中は、この画面の CSP ではなく Worker のスクリプトの応答で決まる（PR3b で考える）。
  # GA はこの画面に出さないので、googletagmanager は許可しない。Material Symbols は Google Fonts から読む。
  content_security_policy do |policy|
    policy.default_src :self
    policy.script_src :self, :wasm_unsafe_eval
    policy.worker_src :self
    policy.connect_src :self
    policy.img_src :self, :data
    policy.style_src :self, "https://fonts.googleapis.com"
    policy.font_src :self, "https://fonts.gstatic.com"
    policy.object_src :none
    policy.base_uri :self
    policy.frame_ancestors :none
  end
  content_security_policy_report_only

  def show
    @message_category = MessageCategory.for_user(current_user).find(params[:message_category_id])
    # スキャンの順番がぶれないよう、同じ position の時は id の順に固定する
    @flow_items = @message_category.flow_items.for_user(current_user).order(:position, :id).load
    @too_many_items = @flow_items.size > ITEM_NOTICE_THRESHOLD

    # 出た先の画面（GA がある）に「前にいたページ」としてこの URL を渡さない・ブラウザに残さない。
    # 付くのは、この画面を表示できた時の応答だけ（カテゴリが見つからない 404 など、例外の応答には付かない）
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Cache-Control"] = "no-store"
  end
end
