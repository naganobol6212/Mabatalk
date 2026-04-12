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
end
