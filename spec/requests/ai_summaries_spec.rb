require 'rails_helper'

RSpec.describe "AiSummaries", type: :request do
  describe "POST /ai_summary" do
    context "未認証ユーザーの場合" do
      it "ログインページにリダイレクトされる" do
        post ai_summary_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みユーザーの場合" do
      let(:user) { create(:user) }

      before { sign_in user }

      context "インターバル未経過（生成から1日以内）の場合" do
        before { create(:message_log, user: user, created_at: 1.day.ago) }

        it "analytics_path にリダイレクトされる" do
          create(:ai_summary, user: user, generated_at: 1.hour.ago)
          post ai_summary_path
          expect(response).to redirect_to(analytics_path)
        end

        it "AiSummaryService が呼ばれない" do
          create(:ai_summary, user: user, generated_at: 1.hour.ago)
          expect(AiSummaryService).not_to receive(:call)
          post ai_summary_path
        end
      end

      context "インターバルの境界値（ちょうど24時間後）の場合" do
        it "再生成できない" do
          freeze_time do
            create(:message_log, user: user, created_at: 1.day.ago)
            create(:ai_summary, user: user, generated_at: 24.hours.ago)
            expect(AiSummaryService).not_to receive(:call)
            post ai_summary_path
          end
        end
      end

      context "ログが0件の場合" do
        it "analytics_path にリダイレクトされる" do
          post ai_summary_path
          expect(response).to redirect_to(analytics_path)
        end

        it "AiSummary が作成されない" do
          expect { post ai_summary_path }.not_to change(AiSummary, :count)
        end

        it "AiSummaryService が呼ばれない" do
          expect(AiSummaryService).not_to receive(:call)
          post ai_summary_path
        end
      end

      context "正常系（ログあり・インターバル経過済み）の場合" do
        before do
          create(:message_log, user: user, created_at: 1.day.ago)
          allow(AiSummaryService).to receive(:call).and_return("テスト用の要約テキスト")
        end

        it "analytics_path にリダイレクトされる" do
          post ai_summary_path
          expect(response).to redirect_to(analytics_path)
        end

        it "AiSummary が新規作成される" do
          expect { post ai_summary_path }.to change(AiSummary, :count).by(1)
        end

        it "content にサービスの戻り値が保存される" do
          post ai_summary_path
          expect(user.reload.ai_summary.content).to eq("テスト用の要約テキスト")
        end

        it "generated_at が更新される" do
          freeze_time do
            post ai_summary_path
            expect(user.reload.ai_summary.generated_at).to be_within(1.second).of(Time.current)
          end
        end
      end

      context "既存の AiSummary を再生成する場合" do
        before do
          create(:ai_summary, user: user, generated_at: 2.days.ago, content: "古い要約")
          create(:message_log, user: user, created_at: 1.day.ago)
          allow(AiSummaryService).to receive(:call).and_return("新しい要約テキスト")
        end

        it "AiSummary が新規作成されず更新される" do
          expect { post ai_summary_path }.not_to change(AiSummary, :count)
        end

        it "content が新しい内容に更新される" do
          post ai_summary_path
          expect(user.reload.ai_summary.content).to eq("新しい要約テキスト")
        end
      end

      context "APIタイムアウトが発生した場合" do
        before do
          create(:message_log, user: user, created_at: 1.day.ago)
          allow(AiSummaryService).to receive(:call).and_raise(Anthropic::Errors::APITimeoutError)
        end

        it "analytics_path にリダイレクトされる" do
          post ai_summary_path
          expect(response).to redirect_to(analytics_path)
        end

        it "AiSummary が作成されない" do
          expect { post ai_summary_path }.not_to change(AiSummary, :count)
        end
      end
    end
  end
end
