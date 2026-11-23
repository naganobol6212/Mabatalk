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

    # 定型文（FlowItem）は「共有（user_id が nil）」か「持ち主本人のもの」だけ使える。
    # 他人の非公開の定型文は、key を知っていても「無いもの」として 404 を返す。
    describe "定型文の公開範囲" do
      let(:user) { create(:user) }
      let(:other_user) { create(:user) }
      let(:shared_item) { create(:flow_item, user: nil, name: "共有の定型文") }
      let(:own_item) { create(:flow_item, user: user, icon_color: "gray", name: "自分の定型文") }
      let(:others_private_item) do
        create(:flow_item, user: other_user, icon_color: "gray", name: "他人の秘密の定型文")
      end

      context "ログイン中のユーザーの場合" do
        before { sign_in user }

        it "共有の定型文は記録でき、完了画面に表示される" do
          expect {
            post message_logs_path, params: { flow_item_key: shared_item.key }
          }.to change { user.message_logs.count }.by(1)
          expect(response).to redirect_to(message_completion_path)

          get message_completion_path
          expect(response.body).to include("共有の定型文")
        end

        it "自分の定型文は記録でき、完了画面に表示される" do
          expect {
            post message_logs_path, params: { flow_item_key: own_item.key }
          }.to change { user.message_logs.count }.by(1)
          expect(response).to redirect_to(message_completion_path)

          get message_completion_path
          expect(response.body).to include("自分の定型文")
        end

        it "他人の非公開の定型文は 404 になり、MessageLog が増えない" do
          expect {
            post message_logs_path, params: { flow_item_key: others_private_item.key }
          }.not_to change(MessageLog, :count)
          expect(response).to have_http_status(:not_found)
        end

        it "他人の非公開の定型文の中身が、履歴にも完了画面にも出ない" do
          post message_logs_path, params: { flow_item_key: others_private_item.key }

          get message_logs_path
          expect(response.body).not_to include("他人の秘密の定型文")
          get message_completion_path
          expect(response.body).not_to include("他人の秘密の定型文")
        end

        it "存在しない key は 404 になり、MessageLog が増えない" do
          expect {
            post message_logs_path, params: { flow_item_key: "no-such-key" }
          }.not_to change(MessageLog, :count)
          expect(response).to have_http_status(:not_found)
        end
      end

      context "ゲスト（未ログイン）の場合" do
        it "共有の定型文は完了画面へ進み、完了画面に表示される" do
          expect {
            post message_logs_path, params: { flow_item_key: shared_item.key }
          }.not_to change(MessageLog, :count)
          expect(response).to redirect_to(message_completion_path)
          expect(session[:last_flow_item_key]).to eq(shared_item.key)

          get message_completion_path
          expect(response.body).to include("共有の定型文")
        end

        it "他人の非公開の定型文は 404 になり、session に入らない" do
          post message_logs_path, params: { flow_item_key: others_private_item.key }

          expect(response).to have_http_status(:not_found)
          expect(session[:last_flow_item_key]).to be_nil
        end

        it "他人の非公開の定型文の中身が、完了画面に出ない" do
          post message_logs_path, params: { flow_item_key: others_private_item.key }

          get message_completion_path
          expect(response.body).not_to include("他人の秘密の定型文")
        end

        it "存在しない key は 404 になる" do
          post message_logs_path, params: { flow_item_key: "no-such-key" }
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
