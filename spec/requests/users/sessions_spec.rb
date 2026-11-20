require 'rails_helper'
require 'support/login_state_helpers'

RSpec.describe "Users::Sessions", type: :request do
  let(:password) { "correct-password" }
  let!(:user) { create(:user, email: "taro@example.com", password: password) }

  describe "GET /users/sign_in" do
    it "ログイン画面が表示される" do
      get new_user_session_path
      expect(response).to have_http_status(:ok)
    end

    it "ログイン済みならカテゴリ一覧へリダイレクトされる" do
      sign_in user
      get new_user_session_path
      expect(response).to redirect_to(message_categories_path)
    end
  end

  describe "POST /users/sign_in" do
    it "正しいメールアドレスとパスワードでログインでき、カテゴリ一覧へリダイレクトされる" do
      post user_session_path, params: { user: { email: "taro@example.com", password: password } }

      expect(response).to redirect_to(message_categories_path)
      expect_logged_in
    end

    it "パスワードが誤っているとログインできず、ログイン画面が再表示される" do
      post user_session_path, params: { user: { email: "taro@example.com", password: "wrong-password" } }

      expect(response).to have_http_status(422)
      expect(response.body).to include(I18n.t("devise.failure.invalid", authentication_keys: User.human_attribute_name(:email)))
      expect_logged_out
    end

    it "未登録のメールアドレスではログインできず、ログイン画面が再表示される" do
      post user_session_path, params: { user: { email: "nobody@example.com", password: password } }

      expect(response).to have_http_status(422)
      expect_logged_out
    end

    it "パスワードが空だとログインできない" do
      post user_session_path, params: { user: { email: "taro@example.com", password: "" } }

      expect(response).to have_http_status(422)
      expect_logged_out
    end
  end

  describe "DELETE /users/sign_out" do
    it "ログアウトするとトップへリダイレクトされ、ログイン必須の画面を開けなくなる" do
      post user_session_path, params: { user: { email: "taro@example.com", password: password } }
      expect_logged_in

      delete destroy_user_session_path

      expect(response).to redirect_to(root_path)
      expect_logged_out
    end
  end
end
