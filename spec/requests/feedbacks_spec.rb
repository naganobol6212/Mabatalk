require 'rails_helper'

RSpec.describe "Feedbacks", type: :request do
  describe "GET /feedbacks/new" do
    context "未認証ユーザーの場合" do
      it "正常にフォームが表示される（匿名送信OK）" do
        get new_feedback_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "認証済みユーザーの場合" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "正常にフォームが表示される" do
        get new_feedback_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "POST /feedbacks" do
    let(:valid_params) do
      { feedback: { category: "bug", body: "テスト本文" } }
    end

    context "未認証ユーザーの場合" do
      it "Feedback が user_id なしで作成される" do
        expect { post feedbacks_path, params: valid_params }
          .to change(Feedback, :count).by(1)
        expect(Feedback.last.user_id).to be_nil
      end

      it "settings_path にリダイレクトされる" do
        post feedbacks_path, params: valid_params
        expect(response).to redirect_to(settings_path)
      end

      it "成功 flash が表示される" do
        post feedbacks_path, params: valid_params
        expect(flash[:notice]).to eq(I18n.t("feedbacks.create.success"))
      end

      it "メールがエンキューされる" do
        expect {
          post feedbacks_path, params: valid_params
        }.to have_enqueued_mail(FeedbackMailer, :notify_admin)
      end
    end

    context "認証済みユーザーの場合" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "Feedback が current_user に紐づいて作成される" do
        post feedbacks_path, params: valid_params
        expect(Feedback.last.user).to eq(user)
      end

      context "1日の送信上限を超えていない場合" do
        before { create_list(:feedback, FeedbacksController::RATE_LIMIT_PER_DAY - 1, user: user) }

        it "送信が成功する" do
          expect { post feedbacks_path, params: valid_params }
            .to change(Feedback, :count).by(1)
        end
      end

      context "1日の送信上限ちょうどの場合" do
        before { create_list(:feedback, FeedbacksController::RATE_LIMIT_PER_DAY, user: user) }

        it "送信が拒否される" do
          expect { post feedbacks_path, params: valid_params }
            .not_to change(Feedback, :count)
        end

        it "new_feedback_path にリダイレクトされる" do
          post feedbacks_path, params: valid_params
          expect(response).to redirect_to(new_feedback_path)
        end

        it "alert flash が表示される" do
          post feedbacks_path, params: valid_params
          expect(flash[:alert]).to eq(I18n.t("feedbacks.create.rate_limit_exceeded"))
        end
      end

      context "24時間より前の送信は上限カウントに含まれない" do
        before do
          create_list(:feedback, FeedbacksController::RATE_LIMIT_PER_DAY, user: user, created_at: 2.days.ago)
        end

        it "送信が成功する" do
          expect { post feedbacks_path, params: valid_params }
            .to change(Feedback, :count).by(1)
        end
      end
    end

    context "バリデーションエラーの場合" do
      let(:invalid_params) do
        { feedback: { category: "bug", body: "" } }
      end

      it "Feedback は作成されない" do
        expect { post feedbacks_path, params: invalid_params }
          .not_to change(Feedback, :count)
      end

      it "new テンプレートが再描画される（422）" do
        post feedbacks_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
