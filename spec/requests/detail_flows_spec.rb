require 'rails_helper'

RSpec.describe "DetailFlows", type: :request do
  let(:user) { create(:user) }
  let(:system_flow_item) do
    create(:flow_item, user: nil, key: "test_drink", detail_flow_key: "drink_detail")
  end

  describe "GET /detail_flows/:flow_item_key/step/:step_index" do
    context "未認証ユーザーの場合" do
      it "ログインページにリダイレクトされる" do
        get detail_flow_step_path(system_flow_item.key, 0)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みユーザーの場合" do
      before { sign_in user }

      context "ユーザー固有のFlowItemにアクセスした場合" do
        let(:user_flow_item) do
          create(:flow_item, user: user, key: "user_drink", detail_flow_key: "drink_detail")
        end

        it "message_categories_path にリダイレクトされる" do
          get detail_flow_step_path(user_flow_item.key, 0)
          expect(response).to redirect_to(message_categories_path)
        end
      end

      context "正常系の場合" do
        it "200 OK を返す" do
          get detail_flow_step_path(system_flow_item.key, 0)
          expect(response).to have_http_status(:ok)
        end
      end

      context "ステップをスキップしようとした場合" do
        it "直前のステップにリダイレクトされる" do
          get detail_flow_step_path(system_flow_item.key, 1)
          expect(response).to redirect_to(detail_flow_step_path(system_flow_item.key, 0))
        end
      end
    end
  end

  describe "POST /detail_flows/:flow_item_key/step/:step_index" do
    context "未認証ユーザーの場合" do
      it "ログインページにリダイレクトされる" do
        post detail_flow_step_submit_path(system_flow_item.key, 0), params: { answer: "small" }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みユーザーの場合" do
      before { sign_in user }

      context "ユーザー固有のFlowItemにアクセスした場合" do
        let(:user_flow_item) do
          create(:flow_item, user: user, key: "user_drink", detail_flow_key: "drink_detail")
        end

        it "message_categories_path にリダイレクトされる" do
          post detail_flow_step_submit_path(user_flow_item.key, 0), params: { answer: "small" }
          expect(response).to redirect_to(message_categories_path)
        end
      end

      context "回答なしで送信した場合" do
        it "同じステップが再表示される" do
          post detail_flow_step_submit_path(system_flow_item.key, 0), params: { answer: "" }
          expect(response).to have_http_status(:ok)
        end

        it "MessageLog が作成されない" do
          expect {
            post detail_flow_step_submit_path(system_flow_item.key, 0), params: { answer: "" }
          }.not_to change(MessageLog, :count)
        end
      end

      context "途中のステップを回答した場合" do
        it "次のステップにリダイレクトされる" do
          post detail_flow_step_submit_path(system_flow_item.key, 0), params: { answer: "small" }
          expect(response).to redirect_to(detail_flow_step_path(system_flow_item.key, 1))
        end
      end

      context "最後のステップを回答した場合" do
        before do
          post detail_flow_step_submit_path(system_flow_item.key, 0), params: { answer: "small" }
        end

        it "完了画面にリダイレクトされる" do
          post detail_flow_step_submit_path(system_flow_item.key, 1), params: { answer: "cold" }
          expect(response).to redirect_to(message_completion_path)
        end

        it "正しい引数で DetailFlowCompletionService が呼ばれる" do
          expected_answers = {
            "amount"      => { "value" => "small", "label" => "少し" },
            "temperature" => { "value" => "cold",  "label" => "冷たい" }
          }
          allow(DetailFlowCompletionService).to receive(:call).and_call_original
          post detail_flow_step_submit_path(system_flow_item.key, 1), params: { answer: "cold" }
          expect(DetailFlowCompletionService).to have_received(:call).with(
            hash_including(
              user: user,
              flow_item: system_flow_item,
              answers: expected_answers
            )
          )
        end
      end
    end
  end

  # 詳細フローで使える定型文（FlowItem）は「共有（user_id が nil）」だけ。
  # 他人の非公開の定型文は、key を知っていても「存在しない key」と同じ 404 を返す。
  describe "定型文の公開範囲" do
    let(:other_user) { create(:user) }
    let(:shared_item) do
      create(:flow_item, user: nil, name: "共有の飲みもの", detail_flow_key: "drink_detail")
    end
    let(:others_private_item) do
      create(:flow_item, user: other_user, icon_color: "gray",
                         name: "他人の秘密の定型文", detail_flow_key: "drink_detail")
    end

    context "ログイン中のユーザーの場合" do
      before { sign_in user }

      it "共有の定型文は、表示から回答・完了画面まで進める" do
        get detail_flow_step_path(shared_item.key, 0)
        expect(response).to have_http_status(:ok)

        post detail_flow_step_submit_path(shared_item.key, 0), params: { answer: "small" }
        expect(response).to redirect_to(detail_flow_step_path(shared_item.key, 1))

        expect {
          post detail_flow_step_submit_path(shared_item.key, 1), params: { answer: "cold" }
        }.to change { user.message_logs.count }.by(1)
        expect(response).to redirect_to(message_completion_path)

        get message_completion_path
        expect(response.body).to include("共有の飲みもの")
        expect(response.body).to include("量：少し、温度：冷たい")
      end

      it "他人の非公開の定型文を表示しようとすると 404 になり、session に入らない" do
        get detail_flow_step_path(others_private_item.key, 0)

        expect(response).to have_http_status(:not_found)
        expect(session[:detail_flow]).to be_nil
      end

      it "他人の非公開の定型文に回答を送ると 404 になり、MessageLog が増えず、session に入らない" do
        expect {
          post detail_flow_step_submit_path(others_private_item.key, 0), params: { answer: "small" }
        }.not_to change(MessageLog, :count)

        expect(response).to have_http_status(:not_found)
        expect(session[:detail_flow]).to be_nil
      end

      it "存在しない key を表示しようとすると 404 になる" do
        get detail_flow_step_path("no-such-key", 0)
        expect(response).to have_http_status(:not_found)
      end

      it "存在しない key に回答を送ると 404 になり、MessageLog が増えない" do
        expect {
          post detail_flow_step_submit_path("no-such-key", 0), params: { answer: "small" }
        }.not_to change(MessageLog, :count)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "ゲスト（未ログイン）の場合" do
      it "他人の非公開の定型文でも、ログイン画面へ送られる" do
        get detail_flow_step_path(others_private_item.key, 0)
        expect(response).to redirect_to(new_user_session_path)

        expect {
          post detail_flow_step_submit_path(others_private_item.key, 0), params: { answer: "small" }
        }.not_to change(MessageLog, :count)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
