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
  end
end
