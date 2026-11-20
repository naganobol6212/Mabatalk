require 'rails_helper'

# ログイン必須の画面・操作を、未ログインのまま呼んだときの振る舞いをまとめて確かめる。
# 画面のボタンを隠すだけでは守れないので、URL を直接叩いても弾かれることを保証する。
RSpec.describe "未ログイン時のアクセス制御", type: :request do
  let!(:shared_category) { create(:message_category, user: nil) }
  let!(:shared_item) { create(:flow_item, message_category: shared_category, user: nil, detail_flow_key: "drink_detail") }

  protected_requests = {
    "設定画面" => ->(*) { get settings_path },
    "利用状況（analytics）" => ->(*) { get analytics_path },
    "送信ログ一覧" => ->(*) { get message_logs_path },
    "AI 振り返りの作成" => ->(*) { post ai_summary_path },
    "アカウント編集画面" => ->(*) { get edit_user_registration_path },
    "アカウント更新" => ->(*) { patch user_registration_path, params: { user: { name: "x" } } },
    "カテゴリ作成画面" => ->(*) { get new_message_category_path },
    "カテゴリ作成" => ->(*) { post message_categories_path, params: { message_category: { name: "x" } } },
    "カテゴリ編集画面" => ->(category, _item) { get edit_message_category_path(category) },
    "カテゴリ更新" => ->(category, _item) { patch message_category_path(category), params: { message_category: { name: "x" } } },
    "カテゴリ削除" => ->(category, _item) { delete message_category_path(category) },
    "カテゴリのコピー画面" => ->(category, _item) { get copy_message_category_path(category) },
    "カテゴリの並び替え" => ->(category, _item) { post reorder_message_categories_path, params: { ids: [ category.id ] } },
    "項目作成画面" => ->(category, _item) { get new_message_category_flow_item_path(category) },
    "項目作成" => ->(category, _item) { post message_category_flow_items_path(category), params: { flow_item: { name: "x" } } },
    "項目編集画面" => ->(category, item) { get edit_message_category_flow_item_path(category, item) },
    "項目更新" => ->(category, item) { patch message_category_flow_item_path(category, item), params: { flow_item: { name: "x" } } },
    "項目削除" => ->(category, item) { delete message_category_flow_item_path(category, item) },
    "項目の並び替え" => ->(category, item) { post reorder_message_category_flow_items_path(category), params: { ids: [ item.id ] } },
    "詳細フローの表示" => ->(_category, item) { get detail_flow_step_path(item.key, 0) },
    "詳細フローの回答" => ->(_category, item) { post detail_flow_step_submit_path(item.key, 0), params: { answer: "x" } }
  }

  protected_requests.each do |label, request|
    it "#{label}はログイン画面へリダイレクトされ、データは変わらない" do
      before_state = [ MessageCategory.pluck(:id, :name), FlowItem.pluck(:id, :name), MessageLog.count, AiSummary.count ]

      instance_exec(shared_category, shared_item, &request)

      expect(response).to redirect_to(new_user_session_path)
      expect([ MessageCategory.pluck(:id, :name), FlowItem.pluck(:id, :name), MessageLog.count, AiSummary.count ])
        .to eq(before_state)
    end
  end

  it "管理画面は存在を隠すため 404 になる" do
    get admin_feedbacks_path
    expect(response).to have_http_status(:not_found)
  end
end
