require 'rails_helper'

RSpec.describe "Admin::Feedbacks", type: :request do
  describe "GET /admin/feedbacks" do
    context "未認証ユーザーの場合" do
      it "404 になる（管理画面の存在を隠す）" do
        get admin_feedbacks_path
        expect(response).to have_http_status(:not_found)
      end
    end

    context "非adminユーザーの場合" do
      let(:user) { create(:user, admin: false) }
      before { sign_in user }

      it "404 になる" do
        get admin_feedbacks_path
        expect(response).to have_http_status(:not_found)
      end
    end

    context "adminユーザーの場合" do
      let(:admin_user) { create(:user, admin: true) }
      before { sign_in admin_user }

      it "正常に一覧が表示される" do
        create_list(:feedback, 3)
        get admin_feedbacks_path
        expect(response).to have_http_status(:ok)
      end

      it "ご意見が0件でも正常表示される" do
        get admin_feedbacks_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /admin/feedbacks/:id" do
    let(:feedback) { create(:feedback) }

    context "adminユーザーの場合" do
      let(:admin_user) { create(:user, admin: true) }
      before { sign_in admin_user }

      it "正常に詳細が表示される" do
        get admin_feedback_path(feedback)
        expect(response).to have_http_status(:ok)
      end

      it "存在しないIDの場合 404 になる" do
        get admin_feedback_path(id: 999_999)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "非adminユーザーの場合" do
      let(:user) { create(:user, admin: false) }
      before { sign_in user }

      it "404 になる" do
        get admin_feedback_path(feedback)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
