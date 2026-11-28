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

    # まばたき入力（カメラ）のデータの扱いは、カメラが動く PR3b より前に説明ページへ出しておく
    describe "まばたき入力（カメラ）のデータの扱い" do
      it "プライバシーポリシーに、映像は端末の中だけ・調整値は端末内・解析から外す・端末内データの消し方が書いてある" do
        get privacy_policy_path

        text = Nokogiri::HTML(response.body).text
        expect(text).to include(
          "カメラの映像は、この端末の中だけで目の開き具合の判定に使います",
          "選んだ文はサーバーへ送ります",
          "この端末のブラウザ（localStorage）に保存します",
          "まばたき入力の画面では Google Analytics を読み込みません",
          "ログアウトや退会では消えません",
          "「この端末の調整値を消す」",
          "Google Fonts への通信"
        )
      end

      it "使い方ガイドに、同じ内容の要点とプライバシーポリシーへのリンクがある" do
        get guide_path

        page = Nokogiri::HTML(response.body)
        expect(page.text).to include(
          "映像は端末の中だけで使います",
          "調整値はこの端末に保存します",
          "この画面ではアクセス解析を使いません",
          "調整値の消し方"
        )
        expect(page.at_css("a[href='#{privacy_policy_path(anchor: 'blink-input')}']")).to be_present
      end
    end

    it "ふつうの画面にも Permissions-Policy が付く（カメラはこのサイトだけ、マイクと位置情報は使わない）" do
      get root_path

      expect(response.headers["Permissions-Policy"]).to eq("camera=(self), microphone=(), geolocation=()")
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
