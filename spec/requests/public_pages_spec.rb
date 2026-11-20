require 'rails_helper'

RSpec.describe "画面の表示", type: :request do
  describe "未ログインでも見られる画面" do
    it "トップページが表示され、ログインと新規登録への導線がある" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(href="#{new_user_session_path}"))
      expect(response.body).to include(%(href="#{new_user_registration_path}"))
    end

    {
      "使い方ガイド" => :guide_path,
      "利用規約" => :terms_path,
      "プライバシーポリシー" => :privacy_policy_path,
      "カテゴリ一覧" => :message_categories_path,
      "ご意見フォーム" => :new_feedback_path,
      "パスワード再設定の申込画面" => :new_user_password_path
    }.each do |label, path_helper|
      it "#{label}が表示される" do
        get public_send(path_helper)
        expect(response).to have_http_status(:ok)
      end
    end

    it "ヘルスチェック（/up）が 200 を返す" do
      get rails_health_check_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "ログイン中の画面" do
    let(:user) { create(:user) }

    before { sign_in user }

    it "トップページを開くとカテゴリ一覧へリダイレクトされる" do
      get root_path
      expect(response).to redirect_to(message_categories_path)
    end

    it "設定画面が表示され、ログアウトとアカウント編集への導線がある" do
      get settings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(href="#{destroy_user_session_path}"))
      expect(response.body).to include(%(href="#{edit_user_registration_path}"))
    end

    it "一般ユーザーの設定画面には管理画面へのリンクが出ない" do
      get settings_path
      expect(response.body).not_to include(admin_feedbacks_path)
    end

    it "管理者の設定画面には管理画面へのリンクが出る" do
      sign_in create(:user, admin: true)
      get settings_path
      expect(response.body).to include(%(href="#{admin_feedbacks_path}"))
    end

    %i[guide_path terms_path privacy_policy_path].each do |path_helper|
      it "#{path_helper} はログイン中でも表示される" do
        get public_send(path_helper)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
