require 'rails_helper'
require 'support/login_state_helpers'
require 'support/form_helpers'

# パスワード再設定を利用者の操作の順に通す。
# 申し込み → メールが 1 通届く → メールのリンクを開く → 新しいパスワードを設定 → 新しいパスワードでログイン
RSpec.describe "Users::Passwords", type: :request do
  let!(:user) { create(:user, email: "taro@example.com", password: "old-password") }

  before { ActionMailer::Base.deliveries.clear }

  def request_reset(email = "taro@example.com")
    post user_password_path, params: { user: { email: email } }
  end

  # 届いたメールの中の「パスワードを再設定する」リンク
  def reset_link_in_mail
    mail = ActionMailer::Base.deliveries.last
    Nokogiri::HTML(mail.body.decoded).css("a").map { |a| a["href"] }.find { |href| href.include?("reset_password_token=") }
  end

  def token_in(link)
    Rack::Utils.parse_query(URI.parse(link).query).fetch("reset_password_token")
  end

  def set_new_password(token, password: "new-password", confirmation: password)
    put user_password_path, params: {
      user: { reset_password_token: token, password: password, password_confirmation: confirmation }
    }
  end

  def login_succeeds?(password)
    delete destroy_user_session_path
    post user_session_path, params: { user: { email: "taro@example.com", password: password } }
    response.redirect? && response.location == message_categories_url
  end

  describe "GET /users/password/new" do
    it "申し込み画面が表示される" do
      get new_user_password_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /users/password（再設定の申し込み）" do
    it "登録済みのメールアドレス宛に、再設定リンク付きのメールが 1 通だけ送られる" do
      expect { request_reset }.to change(ActionMailer::Base.deliveries, :size).by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ "taro@example.com" ])
      expect(mail.subject).to eq(I18n.t("devise.mailer.reset_password_instructions.subject"))
      expect(reset_link_in_mail).to start_with(edit_user_password_url)
    end

    it "ログイン画面へリダイレクトされ、送信した旨のメッセージが表示される" do
      request_reset

      expect(response).to redirect_to(new_user_session_path)
      follow_redirect!
      expect(response.body).to include(I18n.t("devise.passwords.send_instructions"))
    end

    it "申し込んだだけではパスワードは変わらない" do
      request_reset

      expect(login_succeeds?("old-password")).to be(true)
    end

    # 現状の設定（Devise の paranoid が無効）での挙動。
    # 登録の有無が画面から分かる点は報告済み。paranoid を有効にするときはこのテストを書き換える。
    it "登録されていないメールアドレスではメールは送られず、申し込み画面が再表示される" do
      expect { request_reset("nobody@example.com") }.not_to change(ActionMailer::Base.deliveries, :size)

      expect(response).to have_http_status(422)
    end

    it "メールアドレスが空だとメールは送られない" do
      expect { request_reset("") }.not_to change(ActionMailer::Base.deliveries, :size)

      expect(response).to have_http_status(422)
    end
  end

  describe "メールのリンクから新しいパスワードを設定する" do
    before { request_reset }

    it "リンクを開くと、新しいパスワードの入力画面が表示される" do
      get reset_link_in_mail

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("user[password]", "user[password_confirmation]")
    end

    # ほかの例は送信先・メソッド・トークンをテストに直接書いている。
    # この例はリンク先の画面のフォームを読み取り、そこに入っている値のまま送る。
    it "リンク先の画面のフォームを、入っている送信先・メソッド・隠しトークンのまま送ると、新しいパスワードで再ログインできる" do
      get reset_link_in_mail
      form = form_containing("input[type='password']")
      password_fields = form.css("input[type='password']").map { |input| [ input["name"], "new-password" ] }

      submit_form(form, hidden_fields(form) + password_fields)

      expect(response).to redirect_to(message_categories_path)
      expect(login_succeeds?("new-password")).to be(true)
      expect(login_succeeds?("old-password")).to be(false)
    end

    it "新しいパスワードを設定するとログイン状態になり、カテゴリ一覧へリダイレクトされる" do
      set_new_password(token_in(reset_link_in_mail))

      expect(response).to redirect_to(message_categories_path)
      expect_logged_in
    end

    it "新しいパスワードでログインでき、古いパスワードではログインできない" do
      set_new_password(token_in(reset_link_in_mail))

      expect(login_succeeds?("new-password")).to be(true)
      expect(login_succeeds?("old-password")).to be(false)
    end

    it "一度使ったリンクのトークンは、もう一度は使えない" do
      token = token_in(reset_link_in_mail)
      set_new_password(token)
      delete destroy_user_session_path

      set_new_password(token, password: "another-password")

      expect(response).to have_http_status(422)
      expect(login_succeeds?("another-password")).to be(false)
      expect(login_succeeds?("new-password")).to be(true)
    end

    it "もう一度申し込むと、古いメールのリンクは使えなくなり、新しいメールのリンクだけが使える" do
      old_token = token_in(reset_link_in_mail)
      request_reset
      new_token = token_in(reset_link_in_mail)

      set_new_password(old_token)
      expect(response).to have_http_status(422)
      expect(login_succeeds?("new-password")).to be(false)

      set_new_password(new_token)
      expect(login_succeeds?("new-password")).to be(true)
    end

    it "確認用パスワードが一致しないと変更されない" do
      set_new_password(token_in(reset_link_in_mail), confirmation: "different-password")

      expect(response).to have_http_status(422)
      expect(login_succeeds?("new-password")).to be(false)
      expect(login_succeeds?("old-password")).to be(true)
    end

    it "6 文字未満のパスワードには変更できない" do
      set_new_password(token_in(reset_link_in_mail), password: "12345")

      expect(response).to have_http_status(422)
      expect(login_succeeds?("12345")).to be(false)
      expect(login_succeeds?("old-password")).to be(true)
    end

    context "リンクの有効期限（8 時間）" do
      it "期限の直前ならパスワードを変更できる" do
        token = token_in(reset_link_in_mail)

        travel_to(8.hours.from_now - 1.minute) do
          set_new_password(token)

          expect(response).to redirect_to(message_categories_path)
          expect(login_succeeds?("new-password")).to be(true)
        end
      end

      it "期限を過ぎると拒否され、パスワードは変わらない" do
        token = token_in(reset_link_in_mail)

        travel_to(8.hours.from_now + 1.minute) do
          set_new_password(token)

          expect(response).to have_http_status(422)
          expect_logged_out
          expect(login_succeeds?("new-password")).to be(false)
          expect(login_succeeds?("old-password")).to be(true)
        end
      end
    end
  end

  describe "正しくないトークン" do
    it "でたらめなトークンでは拒否され、だれのパスワードも変わらない" do
      request_reset

      set_new_password("invalid-token")

      expect(response).to have_http_status(422)
      expect_logged_out
      expect(login_succeeds?("new-password")).to be(false)
      expect(login_succeeds?("old-password")).to be(true)
    end

    it "トークンが空では拒否される" do
      request_reset

      set_new_password("")

      expect(response).to have_http_status(422)
      expect(login_succeeds?("new-password")).to be(false)
    end

    it "トークンなしで入力画面を開くと、ログイン画面へリダイレクトされる" do
      get edit_user_password_path

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
