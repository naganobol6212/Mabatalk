require 'rails_helper'

RSpec.describe "MessageCategories", type: :request do
  describe "GET /message_categories/new" do
    context "未認証のユーザーの場合" do
      it "未認証ユーザーはリダイレクトされる" do
        get new_message_category_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /message_categories/:id/edit" do
    context "認証済みユーザーの場合" do
      it "他ユーザーのカテゴリにアクセスするとエラーになる" do
        user = create(:user)
        other_user = create(:user)
        other_category = create(:message_category, user: other_user)
        sign_in user
        get edit_message_category_path(other_category)
        expect(response).to have_http_status(404)
      end
    end
  end

  describe "POST /message_categories/reorder" do
    context "認証済みユーザーが他ユーザーのIDを混ぜた場合" do
      it "403が返る" do
        user = create(:user)
        other_user = create(:user)
        other_category = create(:message_category, user: other_user)
        sign_in user
        post reorder_message_categories_path, params: { ids: [other_category.id] }
        expect(response).to have_http_status(403)
      end
    end
  end
end
