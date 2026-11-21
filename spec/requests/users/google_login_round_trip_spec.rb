require 'rails_helper'
require 'support/login_state_helpers'

# Google ログインを「ログイン画面のボタンから」往復で通す（omniauth_callbacks_spec.rb の続き）。
# Google 本物には接続しない。OmniAuth のテストモードで、Google から返る認証情報を差し替える。
# こちらで見るのは、画面のボタンが正しい送信先を指すこと、誰としてログインされるか、
# 画面に出るメッセージ、同じ Google アカウントで何度入ってもユーザーが増えないこと。
RSpec.describe "Google ログインの往復", type: :request do
  around do |example|
    original_test_mode = OmniAuth.config.test_mode
    original_logger = OmniAuth.config.logger
    # 差し替える前の認証情報。もともとキーが無かったのか、値が入っていたのかも覚えておく
    had_mock_auth = OmniAuth.config.mock_auth.key?(:google_oauth2)
    original_mock_auth = OmniAuth.config.mock_auth[:google_oauth2]
    OmniAuth.config.test_mode = true
    OmniAuth.config.logger = Logger.new(IO::NULL)
    example.run
  ensure
    if had_mock_auth
      OmniAuth.config.mock_auth[:google_oauth2] = original_mock_auth
    else
      OmniAuth.config.mock_auth.delete(:google_oauth2)
    end
    OmniAuth.config.logger = original_logger
    OmniAuth.config.test_mode = original_test_mode
  end

  def mock_google_auth(uid: "google-uid-1", name: "グーグル太郎", email: "google-taro@example.com")
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2", uid: uid, info: { name: name, email: email }
    )
  end

  # ログイン画面を開き、「Googleでログイン」ボタンのフォームを取り出す
  def google_login_form
    get new_user_session_path
    Nokogiri::HTML(response.body).css("form").find { |form| form.text.include?("Googleでログイン") }
  end

  # 利用者の操作と同じ順番: ボタンを押す（フォームの送信先へ送る）→ Google から戻る → 着いた画面まで進む
  def login_with_google_button
    form = google_login_form
    process form["method"].to_sym, form["action"]
    follow_redirect! while response.redirect?
  end

  # いまログインしているアカウントのユーザー名（アカウント編集画面に表示される）
  def logged_in_name
    get edit_user_registration_path
    Nokogiri::HTML(response.body).at_css("input[name='user[name]']")&.[]("value")
  end

  it "ログイン画面の「Googleでログイン」ボタンは、Google ログインの開始 URL へ POST する" do
    form = google_login_form

    expect(form["action"]).to eq(user_google_oauth2_omniauth_authorize_path)
    expect(form["method"]).to eq("post")
    expect(form.at_css("input[name='_method']")).to be_nil
  end

  context "初めて Google でログインする場合" do
    before { mock_google_auth }

    it "ボタンからカテゴリ一覧まで進み、Google のアカウントとしてログインされ、成功メッセージが表示される" do
      expect { login_with_google_button }.to change(User, :count).by(1)

      expect(request.path).to eq(message_categories_path)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("devise.omniauth_callbacks.success", kind: "Google"))
      expect(logged_in_name).to eq("グーグル太郎")
    end

    it "ログアウトして同じ Google アカウントでもう一度ログインしても、ユーザーは増えず同じアカウントに入る" do
      login_with_google_button
      delete destroy_user_session_path
      expect_logged_out

      expect { login_with_google_button }.not_to change(User, :count)

      expect(logged_in_name).to eq("グーグル太郎")
    end
  end

  context "ほかのユーザーも登録されている場合" do
    let!(:other_user) { create(:user, name: "別の人", email: "other@example.com") }
    let!(:google_user) do
      create(:user, name: "登録済みの太郎", provider: "google_oauth2", uid: "google-uid-1", email: "google-taro@example.com")
    end

    before { mock_google_auth }

    it "Google の ID が一致するユーザー本人としてログインされる（ほかのユーザーにはならない）" do
      expect { login_with_google_button }.not_to change(User, :count)

      expect(logged_in_name).to eq("登録済みの太郎")
    end
  end

  context "Google 側で認証に失敗した場合" do
    before { OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials }

    it "ログイン画面に戻り、失敗のメッセージが表示され、ログインもユーザー作成もされない" do
      expect { login_with_google_button }.not_to change(User, :count)

      expect(request.path).to eq(new_user_session_path)
      expect(response).to have_http_status(:ok)
      # 現状は「GoogleOauth2でのログインに失敗しました」と表示される（サービス名の部分は固定しない）
      expect(response.body).to include("でのログインに失敗しました")
      expect_logged_out
    end
  end
end
