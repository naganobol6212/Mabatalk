require 'rails_helper'

RSpec.describe "MessageCompletions", type: :request do
  describe "GET /message_completion" do
    context "認証済みユーザー・ログありの場合" do
      it "200 OK を返し、最終ログの flow_item_name が表示される" do
        user = create(:user)
        old_item = create(:flow_item, name: "old-name")
        latest_item = create(:flow_item, name: "latest-snapshot-name")
        create(:message_log, user: user, flow_item: old_item, created_at: 2.days.ago)
        create(:message_log, user: user, flow_item: latest_item, created_at: 1.day.ago)
        latest_item.update!(name: "latest-current-name")
        sign_in user
        get message_completion_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("latest-snapshot-name")
        expect(response.body).not_to include("latest-current-name")
      end
    end

    context "認証済みユーザー・ログなしの場合" do
      it "200 OK を返す" do
        user = create(:user)
        sign_in user
        get message_completion_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "未認証ユーザー・session に flow_item_key ありの場合" do
      it "200 OK を返し、flow_item の名前が表示される" do
        flow_item = create(:flow_item)
        # 事前POSTでセッションに flow_item_key を積む
        post message_logs_path, params: { flow_item_key: flow_item.key }
        get message_completion_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(flow_item.name)
      end
    end

    context "未認証ユーザー・session なしの場合" do
      it "200 OK を返す" do
        get message_completion_path
        expect(response).to have_http_status(:ok)
      end
    end

    # ゲストの完了画面は session[:last_flow_item_key] から定型文を引く。
    # 引けるのは「共有（user_id が nil）」だけ。それ以外の key は「見つからない」表示にする。
    describe "ゲストの session に残った定型文の key" do
      let(:not_found_text) { "選択された内容が見つかりませんでした。" }

      # 修正後は、他人の非公開の定型文の key を session に入れる正規の方法がない。
      # そこで「共有のうちに選んで session に key が入り、そのあと他人の非公開になった」
      # という流れで、古いセッションに他人の key が残っている状態を作る。
      it "他人の非公開の定型文の key が残っていても、名前を出さず「見つからない」表示になる" do
        item = create(:flow_item, user: nil, name: "あとで非公開になる定型文")
        post message_logs_path, params: { flow_item_key: item.key }
        item.update!(user: create(:user), icon_color: "gray")

        get message_completion_path

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("あとで非公開になる定型文")
        expect(response.body).to include(not_found_text)
      end

      it "もう存在しない定型文の key が残っている場合も、同じ「見つからない」表示になる" do
        item = create(:flow_item, user: nil, name: "あとで消える定型文")
        post message_logs_path, params: { flow_item_key: item.key }
        item.destroy!

        get message_completion_path

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("あとで消える定型文")
        expect(response.body).to include(not_found_text)
      end
    end
  end
end
