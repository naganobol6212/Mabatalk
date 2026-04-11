require 'rails_helper'

RSpec.describe "Analytics", type: :request do
  describe "GET /analytics" do
    context "未認証ユーザーの場合" do
      it "ログインページにリダイレクトされる" do
        get analytics_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みユーザーの場合" do
      let(:user) { create(:user) }

      before { sign_in user }

      context "正常系の場合" do
        it "200 OK を返す" do
          get analytics_path
          expect(response).to have_http_status(:ok)
        end
      end

      context "params[:month] に正しい値を渡した場合" do
        it "200 OK を返す" do
          get analytics_path, params: { month: "2026-03" }
          expect(response).to have_http_status(:ok)
        end
      end

      context "params[:month] が空の場合" do
        it "当月で 200 OK を返す" do
          get analytics_path, params: { month: "" }
          expect(response).to have_http_status(:ok)
        end
      end

      context "params[:month] が不正な値の場合" do
        it "当月にフォールバックして 200 OK を返す" do
          get analytics_path, params: { month: "invalid" }
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end
end
