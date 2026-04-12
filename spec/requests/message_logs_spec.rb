require 'rails_helper'

RSpec.describe "MessageLogs", type: :request do
  describe "GET /message_logs" do
    context "未認証ユーザーの場合" do
      it "未認証ユーザーはリダイレクトされる" do
        get message_logs_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みユーザーの場合" do
      it "自分のログを取得できる" do
        user = create(:user)
        sign_in user
        get message_logs_path
        expect(response).to have_http_status(:ok)
      end

      it "他ユーザーのログが含まれない" do
        user = create(:user)
        other_user = create(:user)
        sign_in user
        my_log = create(:message_log, user: user)
        other_log = create(:message_log, user: other_user)
        get message_logs_path
        expect(response.body).to include(my_log.flow_item_name)
        expect(response.body).not_to include(other_log.flow_item_name)
      end
    end
  end

  describe "POST /message_logs" do
    context "未認証ユーザーの場合" do
      it "MessageLogが作成されない" do
        flow_item = create(:flow_item)
        expect { post message_logs_path,
          params: { flow_item_key: flow_item.key }
        }.not_to change(MessageLog, :count)
      end
    end

    context "認証ユーザーの場合" do
      it "MessageLogが作成される" do
        user = create(:user)
        sign_in user
        flow_item = create(:flow_item)
        expect { post message_logs_path,
          params: { flow_item_key: flow_item.key }
        }.to change(MessageLog, :count)
      end

      it "message_completion_path にリダイレクトされる" do
        user = create(:user)
        sign_in user
        flow_item = create(:flow_item)
        post message_logs_path, params: { flow_item_key: flow_item.key }
        expect(response).to redirect_to(message_completion_path)
      end
    end

    context "未認証ユーザーの場合" do
      it "session[:last_flow_item_key] に flow_item のキーが保存される" do
        flow_item = create(:flow_item)
        post message_logs_path, params: { flow_item_key: flow_item.key }
        expect(session[:last_flow_item_key]).to eq(flow_item.key)
      end
    end
  end
end
