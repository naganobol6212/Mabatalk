require 'rails_helper'
require 'support/login_state_helpers'

# 「ログインしたままにする」（remember me）を確かめる。
# チェックを入れてログインすると remember の cookie が付き、ブラウザを閉じて
# セッションが消えても、その cookie でログイン状態が戻る。
RSpec.describe "ログインしたままにする（remember me）", type: :request do
  let(:password) { "correct-password" }
  let!(:user) { create(:user, email: "taro@example.com", password: password) }

  let(:remember_cookie_name) { "remember_user_token" }
  let(:session_cookie_name) { Rails.application.config.session_options[:key] }

  def login(remember_me:)
    post user_session_path, params: { user: { email: "taro@example.com", password: password, remember_me: remember_me } }
    expect(response).to redirect_to(message_categories_path)
  end

  # ブラウザを閉じて開き直した状態（セッションの cookie だけが消える）
  def close_and_reopen_browser
    cookies.delete(session_cookie_name)
  end

  # まっさらなブラウザに、控えておいた remember の cookie だけを持たせる
  # （cookie を盗まれた・期限切れの cookie を送り続けた、という場面の再現）
  def new_browser_with(remember_cookie)
    reset!
    cookies[remember_cookie_name] = remember_cookie
  end

  it "ログイン画面に「ログインしたままにする」のチェックボックスがある" do
    get new_user_session_path

    expect(Nokogiri::HTML(response.body).at_css("input[type='checkbox'][name='user[remember_me]']")).to be_present
  end

  context "「ログインしたままにする」にチェックを入れてログインした場合" do
    before { login(remember_me: "1") }

    it "remember の cookie が付く（JavaScript から読めない HttpOnly で、期限は 2 週間後）" do
      expect(cookies[remember_cookie_name]).to be_present

      set_cookie = Array(response.headers["Set-Cookie"]).flat_map { |line| line.split("\n") }
                                                        .find { |line| line.start_with?("#{remember_cookie_name}=") }
      expect(set_cookie).to match(/;\s*httponly/i)
      expires = Time.zone.parse(set_cookie[/expires=([^;]+)/i, 1])
      expect(expires).to be_within(1.minute).of(2.weeks.from_now)
    end

    it "セッションが消えても、remember の cookie でログイン状態が戻る" do
      close_and_reopen_browser

      expect_logged_in
    end

    it "remember の cookie だけを持つ別のブラウザでも、期限内ならログイン状態になる" do
      remember_cookie = cookies[remember_cookie_name]

      travel_to(2.weeks.from_now - 1.hour) do
        new_browser_with(remember_cookie)

        expect_logged_in
      end
    end

    it "期限（2 週間）を過ぎた remember の cookie では、ログイン状態は戻らない" do
      remember_cookie = cookies[remember_cookie_name]

      travel_to(2.weeks.from_now + 1.hour) do
        new_browser_with(remember_cookie)

        expect_logged_out
      end
    end

    it "ログアウトすると remember の cookie が消え、セッションが消えたあとはログイン状態に戻らない" do
      delete destroy_user_session_path

      expect(cookies[remember_cookie_name]).to be_blank
      close_and_reopen_browser
      expect_logged_out
    end

    it "ログアウト前に控えた remember の cookie は、ログアウト後には使えない" do
      remember_cookie = cookies[remember_cookie_name]
      delete destroy_user_session_path

      new_browser_with(remember_cookie)

      expect_logged_out
    end

    it "パスワードを変更すると、変更前の remember の cookie は使えなくなる" do
      remember_cookie = cookies[remember_cookie_name]
      patch user_registration_path, params: {
        user: { current_password: password, password: "new-password", password_confirmation: "new-password" }
      }
      expect(response).to redirect_to(settings_path)

      new_browser_with(remember_cookie)

      expect_logged_out
    end
  end

  context "チェックを入れずにログインした場合" do
    before { login(remember_me: "0") }

    it "remember の cookie は付かず、セッションが消えるとログイン状態は戻らない" do
      expect(cookies[remember_cookie_name]).to be_blank
      expect_logged_in

      close_and_reopen_browser

      expect_logged_out
    end
  end

  it "でたらめな remember の cookie ではログイン状態にならない" do
    new_browser_with("invalid-remember-token")

    expect_logged_out
  end
end
