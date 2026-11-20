require 'rails_helper'
require 'support/login_state_helpers'

RSpec.describe "Users::Registrations", type: :request do
  describe "GET /users/sign_up" do
    it "新規登録画面が表示される" do
      get new_user_registration_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /users" do
    let(:valid_params) do
      { name: "山田花子", email: "hanako@example.com", password: "password123", password_confirmation: "password123" }
    end

    def sign_up(overrides = {})
      post user_registration_path, params: { user: valid_params.merge(overrides) }
    end

    it "名前・メールアドレス・パスワードで登録でき、ログイン状態でカテゴリ一覧へリダイレクトされる" do
      expect { sign_up }.to change(User, :count).by(1)

      expect(response).to redirect_to(message_categories_path)
      expect(User.find_by(email: "hanako@example.com").name).to eq("山田花子")
      expect_logged_in
    end

    it "登録したメールアドレスとパスワードで、あとからログインできる" do
      sign_up
      delete destroy_user_session_path

      post user_session_path, params: { user: { email: "hanako@example.com", password: "password123" } }

      expect(response).to redirect_to(message_categories_path)
      expect_logged_in
    end

    {
      "名前が空" => { name: "" },
      "メールアドレスが空" => { email: "" },
      "パスワードと確認用パスワードが一致しない" => { password_confirmation: "different123" },
      "パスワードに空白文字が入っている" => { password: "pass word123", password_confirmation: "pass word123" },
      "パスワードが 6 文字未満" => { password: "12345", password_confirmation: "12345" }
    }.each do |reason, overrides|
      it "#{reason}と登録できず、登録画面が再表示される" do
        expect { sign_up(overrides) }.not_to change(User, :count)

        expect(response).to have_http_status(422)
        expect_logged_out
      end
    end

    it "すでに登録済みのメールアドレスでは登録できない" do
      create(:user, email: "hanako@example.com")

      expect { sign_up }.not_to change(User, :count)

      expect(response).to have_http_status(422)
      expect_logged_out
    end
  end

  describe "GET /users/edit" do
    it "未ログインならログイン画面へリダイレクトされる" do
      get edit_user_registration_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "ログイン中ならアカウント編集画面が表示される" do
      sign_in create(:user)
      get edit_user_registration_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /users" do
    let(:user) { create(:user, name: "変更前", email: "before@example.com", password: "old-password") }

    def login_succeeds?(email:, password:)
      delete destroy_user_session_path
      post user_session_path, params: { user: { email: email, password: password } }
      response.redirect? && response.location == message_categories_url
    end

    before { sign_in user }

    it "名前は現在のパスワードなしで変更でき、設定画面へリダイレクトされる" do
      patch user_registration_path, params: { user: { name: "変更後" } }

      expect(response).to redirect_to(settings_path)
      expect(user.reload.name).to eq("変更後")
    end

    it "現在のパスワードが正しければパスワードを変更でき、新しいパスワードでログインできる" do
      patch user_registration_path, params: {
        user: { current_password: "old-password", password: "new-password", password_confirmation: "new-password" }
      }

      expect(response).to redirect_to(settings_path)
      expect(login_succeeds?(email: "before@example.com", password: "new-password")).to be(true)
    end

    it "現在のパスワードが誤っているとパスワードを変更できない" do
      patch user_registration_path, params: {
        user: { current_password: "wrong-password", password: "new-password", password_confirmation: "new-password" }
      }

      expect(response).to have_http_status(422)
      expect(login_succeeds?(email: "before@example.com", password: "new-password")).to be(false)
      expect(login_succeeds?(email: "before@example.com", password: "old-password")).to be(true)
    end

    it "現在のパスワードを入力せずにパスワードを変更することはできない" do
      patch user_registration_path, params: {
        user: { current_password: "", password: "new-password", password_confirmation: "new-password" }
      }

      expect(response).to have_http_status(422)
      expect(login_succeeds?(email: "before@example.com", password: "new-password")).to be(false)
    end

    it "新しいパスワードが空のままだとエラーになり、パスワードは変わらない" do
      patch user_registration_path, params: {
        user: { current_password: "old-password", password: "", password_confirmation: "" }
      }

      expect(response).to have_http_status(422)
      expect(login_succeeds?(email: "before@example.com", password: "old-password")).to be(true)
    end

    it "現在のパスワードが正しければメールアドレスを変更できる" do
      patch user_registration_path, params: { user: { email: "after@example.com", current_password: "old-password" } }

      expect(response).to redirect_to(settings_path)
      expect(user.reload.email).to eq("after@example.com")
    end

    it "現在のパスワードが誤っているとメールアドレスを変更できない" do
      patch user_registration_path, params: { user: { email: "after@example.com", current_password: "wrong-password" } }

      expect(response).to have_http_status(422)
      expect(user.reload.email).to eq("before@example.com")
    end
  end

  describe "DELETE /users" do
    let(:user) { create(:user, email: "leaver@example.com", password: "leave-password") }

    it "未ログインでは退会できず、ログイン画面へリダイレクトされる" do
      user

      expect { delete user_registration_path }.not_to change(User, :count)
      expect(response).to redirect_to(new_user_session_path)
    end

    context "ログイン中の場合" do
      before { sign_in user }

      it "ご意見と共通カテゴリの自作項目を持つユーザーでも退会できる" do
        feedback = create(:feedback, user: user)
        shared_category = create(:message_category, user: nil)
        own_item = create(:flow_item, message_category: shared_category, user: user)

        expect { delete user_registration_path }.to change(User, :count).by(-1)
        expect(response).to redirect_to(root_path)
        expect(feedback.reload.user_id).to be_nil
        expect(FlowItem.exists?(own_item.id)).to be(false)
      end

      it "退会するとログアウトされ、同じメールアドレスとパスワードではログインできなくなる" do
        delete user_registration_path

        expect(response).to redirect_to(root_path)
        expect_logged_out

        post user_session_path, params: { user: { email: "leaver@example.com", password: "leave-password" } }
        expect(response).to have_http_status(422)
        expect_logged_out
      end

      it "自作のカテゴリ・項目・送信ログは消える" do
        own_category = create(:message_category, user: user)
        own_item = create(:flow_item, message_category: own_category, user: user)
        own_log = create(:message_log, user: user, flow_item: own_item)

        delete user_registration_path

        expect(MessageCategory.exists?(own_category.id)).to be(false)
        expect(FlowItem.exists?(own_item.id)).to be(false)
        expect(MessageLog.exists?(own_log.id)).to be(false)
      end

      it "共通データと他のユーザーのデータは残る" do
        shared_category = create(:message_category, user: nil)
        shared_item = create(:flow_item, message_category: shared_category, user: nil)
        create(:message_log, user: user, flow_item: shared_item)
        other_user = create(:user)
        other_category = create(:message_category, user: other_user)
        other_item = create(:flow_item, message_category: other_category, user: other_user)
        other_log = create(:message_log, user: other_user, flow_item: shared_item)

        delete user_registration_path

        expect(MessageCategory.exists?(shared_category.id)).to be(true)
        expect(FlowItem.exists?(shared_item.id)).to be(true)
        expect(User.exists?(other_user.id)).to be(true)
        expect(MessageCategory.exists?(other_category.id)).to be(true)
        expect(FlowItem.exists?(other_item.id)).to be(true)
        expect(MessageLog.exists?(other_log.id)).to be(true)
      end
    end
  end
end
