require 'rails_helper'
require 'support/login_state_helpers'

# CSRF（他のサイトから勝手にフォームを送らせる攻撃）への対策を確かめる。
# test 環境では CSRF 保護が無効なので、この spec の中だけ本番と同じ「有効」にして、終わったら戻す。
# 正しいトークン付きの送信は通り、トークンなし・でたらめなトークンの送信は 422 で拒否される。
RSpec.describe "CSRF 保護", type: :request do
  around do |example|
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  let(:password) { "correct-password" }
  let!(:user) { create(:user, email: "taro@example.com", password: password) }

  # 画面を開き、その中のフォーム（送信先が action のもの）に埋め込まれたトークンを取り出す
  def form_token(page_path, action:)
    get page_path
    Nokogiri::HTML(response.body).at_css("form[action='#{action}'] input[name='authenticity_token']")["value"]
  end

  # 画面の <meta name="csrf-token">（Turbo がリンクやボタンの送信に付けるトークン）を取り出す
  def meta_token(page_path)
    get page_path
    Nokogiri::HTML(response.body).at_css("meta[name='csrf-token']")["content"]
  end

  # 別のブラウザ（別のセッション）で発行されたトークン
  def token_from_another_browser
    other = open_session
    other.get new_user_session_path
    Nokogiri::HTML(other.response.body).at_css("meta[name='csrf-token']")["content"]
  end

  shared_examples "トークンが正しくない送信を拒否する" do
    it "トークンなしは 422 で拒否される" do
      submit(nil)
      expect(response).to have_http_status(422)
      expect_nothing_happened
    end

    it "でたらめなトークンは 422 で拒否される" do
      submit("invalid-token")
      expect(response).to have_http_status(422)
      expect_nothing_happened
    end

    it "別のブラウザで発行されたトークンは 422 で拒否される" do
      submit(token_from_another_browser)
      expect(response).to have_http_status(422)
      expect_nothing_happened
    end
  end

  describe "ログイン" do
    def submit(token)
      post user_session_path, params: { user: { email: "taro@example.com", password: password }, authenticity_token: token }.compact
    end

    def expect_nothing_happened
      expect_logged_out
    end

    it "ログイン画面のフォームのトークン付きならログインできる" do
      submit(form_token(new_user_session_path, action: user_session_path))

      expect(response).to redirect_to(message_categories_path)
      expect_logged_in
    end

    it_behaves_like "トークンが正しくない送信を拒否する"
  end

  describe "ご意見の送信" do
    def send_feedback(token)
      post feedbacks_path, params: { feedback: { category: "bug", body: "テスト本文" }, authenticity_token: token }.compact
    end

    # 拒否される 3 つの例から呼ばれる。管理者への通知メールは後から送る（deliver_later）ので、
    # 届いたメールの一覧（deliveries）ではなく「送信待ちのキューに入らないこと」を、送信をはさんで確かめる。
    def submit(token)
      expect { send_feedback(token) }.not_to have_enqueued_mail(FeedbackMailer, :notify_admin)
    end

    def expect_nothing_happened
      expect(Feedback.count).to eq(0)
    end

    it "送信フォームのトークン付きなら保存され、管理者への通知メールが送信待ちに入る" do
      token = form_token(new_feedback_path, action: feedbacks_path)

      expect { send_feedback(token) }
        .to change(Feedback, :count).by(1)
        .and have_enqueued_mail(FeedbackMailer, :notify_admin)
      expect(response).to redirect_to(settings_path)
    end

    it_behaves_like "トークンが正しくない送信を拒否する"
  end

  describe "新規登録" do
    def submit(token)
      post user_registration_path, params: {
        user: { name: "山田花子", email: "hanako@example.com", password: "password123", password_confirmation: "password123" },
        authenticity_token: token
      }.compact
    end

    def expect_nothing_happened
      expect(User.exists?(email: "hanako@example.com")).to be(false)
      expect_logged_out
    end

    it "登録フォームのトークン付きなら登録できる" do
      token = form_token(new_user_registration_path, action: user_registration_path)

      expect { submit(token) }.to change(User, :count).by(1)
      expect_logged_in
    end

    it_behaves_like "トークンが正しくない送信を拒否する"
  end

  describe "パスワード再設定の申し込み" do
    def submit(token)
      post user_password_path, params: { user: { email: "taro@example.com" }, authenticity_token: token }.compact
    end

    def expect_nothing_happened
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    before { ActionMailer::Base.deliveries.clear }

    it "申し込みフォームのトークン付きならメールが送られる" do
      token = form_token(new_user_password_path, action: user_password_path)

      expect { submit(token) }.to change(ActionMailer::Base.deliveries, :size).by(1)
    end

    it_behaves_like "トークンが正しくない送信を拒否する"
  end

  describe "ログイン中の操作" do
    # 先に画面を 1 つ開いて、ログイン済みのセッション cookie を持った状態にする
    before do
      sign_in user
      get settings_path
    end

    describe "ログアウト" do
      def submit(token)
        delete destroy_user_session_path, headers: { "X-CSRF-Token" => token }.compact
      end

      def expect_nothing_happened
        expect_logged_in
      end

      it "設定画面のトークン付きならログアウトできる" do
        submit(meta_token(settings_path))

        expect(response).to redirect_to(root_path)
        expect_logged_out
      end

      it_behaves_like "トークンが正しくない送信を拒否する"
    end

    describe "退会（アカウント削除）" do
      def submit(token)
        delete user_registration_path, params: { authenticity_token: token }.compact
      end

      def expect_nothing_happened
        expect(User.exists?(user.id)).to be(true)
        expect_logged_in
      end

      it "アカウント編集画面の削除ボタンのトークン付きなら退会できる" do
        get edit_user_registration_path
        delete_form = Nokogiri::HTML(response.body)
                              .css("form[action='#{user_registration_path}']")
                              .find { |form| form.at_css("input[name='_method'][value='delete']") }
        submit(delete_form.at_css("input[name='authenticity_token']")["value"])

        expect(response).to redirect_to(root_path)
        expect(User.exists?(user.id)).to be(false)
      end

      it_behaves_like "トークンが正しくない送信を拒否する"
    end

    describe "アカウント情報の変更" do
      def submit(token)
        patch user_registration_path, params: { user: { name: "書き換えられた名前" }, authenticity_token: token }.compact
      end

      def expect_nothing_happened
        expect(user.reload.name).not_to eq("書き換えられた名前")
      end

      it "画面のトークン付きなら変更できる" do
        submit(meta_token(edit_user_registration_path))

        expect(response).to redirect_to(settings_path)
        expect(user.reload.name).to eq("書き換えられた名前")
      end

      it_behaves_like "トークンが正しくない送信を拒否する"
    end
  end

  # Google ログインの開始（POST /users/auth/google_oauth2）は Rails のコントローラーではなく
  # OmniAuth のミドルウェアが受ける。omniauth-rails_csrf_protection がここでもトークンを確かめる。
  describe "Google ログインの開始" do
    around do |example|
      original_test_mode = OmniAuth.config.test_mode
      original_logger = OmniAuth.config.logger
      # 差し替える前の認証情報。もともとキーが無かったのか、値が入っていたのかも覚えておく
      had_mock_auth = OmniAuth.config.mock_auth.key?(:google_oauth2)
      original_mock_auth = OmniAuth.config.mock_auth[:google_oauth2]
      OmniAuth.config.test_mode = true
      OmniAuth.config.logger = Logger.new(IO::NULL)
      OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
        provider: "google_oauth2", uid: "google-uid-1", info: { name: "グーグル太郎", email: "google-taro@example.com" }
      )
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

    def submit(token)
      post user_google_oauth2_omniauth_authorize_path, params: { authenticity_token: token }.compact
    end

    def expect_nothing_happened
      expect(User.exists?(email: "google-taro@example.com")).to be(false)
      expect_logged_out
    end

    it "ログイン画面の Google ボタンのトークン付きなら Google ログインへ進み、ログインできる" do
      submit(form_token(new_user_session_path, action: user_google_oauth2_omniauth_authorize_path))

      expect(response).to redirect_to(user_google_oauth2_omniauth_callback_path)
      follow_redirect!
      expect_logged_in
    end

    it_behaves_like "トークンが正しくない送信を拒否する"
  end
end
