require 'rails_helper'
require 'support/login_state_helpers'

# Google 本物には接続しない。OmniAuth のテストモードで、Google から返る認証情報を差し替える。
RSpec.describe "Users::OmniauthCallbacks", type: :request do
  around do |example|
    original_test_mode = OmniAuth.config.test_mode
    OmniAuth.config.test_mode = true
    example.run
  ensure
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.test_mode = original_test_mode
  end

  def mock_google_auth(uid: "google-uid-1", name: "グーグル太郎", email: "google-taro@example.com")
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: { name: name, email: email }
    )
  end

  # 利用者の操作と同じ順番: 「Google でログイン」ボタン（POST）→ Google から戻る（コールバック）
  def login_with_google
    post user_google_oauth2_omniauth_authorize_path
    expect(response).to redirect_to(user_google_oauth2_omniauth_callback_path)
    follow_redirect!
  end

  describe "Google ログイン" do
    context "初めて Google でログインする場合" do
      before { mock_google_auth }

      it "ユーザーが作成され、ログイン状態でカテゴリ一覧へリダイレクトされる" do
        expect { login_with_google }.to change(User, :count).by(1)

        expect(response).to redirect_to(message_categories_path)
        expect(User.find_by(email: "google-taro@example.com")).to have_attributes(
          name: "グーグル太郎", provider: "google_oauth2", uid: "google-uid-1"
        )
        expect_logged_in
      end
    end

    context "同じ Google アカウントで登録済みの場合" do
      let!(:existing_user) do
        create(:user, provider: "google_oauth2", uid: "google-uid-1", email: "google-taro@example.com")
      end

      before { mock_google_auth }

      it "ユーザーを増やさずにログインでき、カテゴリ一覧へリダイレクトされる" do
        expect { login_with_google }.not_to change(User, :count)

        expect(response).to redirect_to(message_categories_path)
        expect_logged_in
      end
    end

    context "同じメールアドレスがメール+パスワードで登録済みの場合" do
      let!(:email_user) { create(:user, email: "google-taro@example.com") }

      before { mock_google_auth }

      # 現状の仕様: 既存アカウントとは自動で紐付けず、エラーを表示してログインさせない。
      # （他人のアカウントに入れないこと・重複ユーザーを作らないことを守る）
      it "ユーザーは作られず、ログインもされず、エラーが表示される" do
        expect { login_with_google }.not_to change(User, :count)

        expect(response).to have_http_status(:redirect)
        expect(email_user.reload).to have_attributes(provider: nil, uid: nil)
        follow_redirect!
        expect(response.body).to include("メールアドレスはすでに登録されています")
        expect_logged_out
      end
    end

    context "Google 側で認証に失敗した場合" do
      before { OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials }

      it "ユーザーは作られず、ログイン画面へリダイレクトされる" do
        expect { login_with_google }.not_to change(User, :count)

        expect(response).to redirect_to(new_user_session_path)
        expect_logged_out
      end
    end

    it "GET では Google ログインを開始できない（CSRF 対策）" do
      mock_google_auth
      get user_google_oauth2_omniauth_authorize_path

      expect(response).to have_http_status(:not_found)
      expect(User.count).to eq(0)
    end
  end
end
