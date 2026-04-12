require 'rails_helper'

RSpec.describe "MessageCategories", type: :request do
  let(:user) { create(:user) }
  let(:category) { create(:message_category, user: user) }

  describe "GET /message_categories" do
    context "認証済みユーザーの場合" do
      before { sign_in user }

      it "200 OK を返す" do
        get message_categories_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /message_categories/new" do
    context "未認証ユーザーの場合" do
      it "ログインページにリダイレクトされる" do
        get new_message_category_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みユーザーの場合" do
      before { sign_in user }

      it "200 OK を返す" do
        get new_message_category_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /message_categories/:id/copy" do
    context "認証済みユーザーの場合" do
      before { sign_in user }

      it "システムカテゴリをプリフィルして 200 OK を返す" do
        system_category = create(:message_category, user: nil)
        get copy_message_category_path(system_category)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "POST /message_categories" do
    before { sign_in user }

    let(:valid_params) do
      {
        message_category: {
          name: "テストカテゴリ",
          kana: "てすとかてごり",
          icon: IconDefinitions::CATEGORY_ICONS.keys.first,
          icon_color: IconDefinitions::ICON_COLORS.keys.first
        }
      }
    end

    context "正常系の場合" do
      it "message_categories_path にリダイレクトされる" do
        post message_categories_path, params: valid_params
        expect(response).to redirect_to(message_categories_path)
      end
    end

    context "バリデーションエラーの場合" do
      it "422 を返す" do
        post message_categories_path, params: {
          message_category: { name: "", kana: "", icon: IconDefinitions::CATEGORY_ICONS.keys.first }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "コピー元カテゴリがある場合" do
      let(:system_category) { create(:message_category, user: nil) }
      let!(:system_flow_item) do
        create(:flow_item, message_category: system_category, user: nil)
      end

      it "flow_items_path にリダイレクトされる" do
        post message_categories_path, params: valid_params.merge(source_category_id: system_category.id)
        new_category = user.message_categories.last
        expect(response).to redirect_to(message_category_flow_items_path(new_category))
      end

      it "FlowItem がコピーされる" do
        expect {
          post message_categories_path, params: valid_params.merge(source_category_id: system_category.id)
        }.to change { user.reload.message_categories.last&.flow_items&.count }.from(nil).to(1)
      end
    end
  end

  describe "GET /message_categories/:id/edit" do
    context "認証済みユーザーの場合" do
      before { sign_in user }

      it "200 OK を返す" do
        get edit_message_category_path(category)
        expect(response).to have_http_status(:ok)
      end

      it "他ユーザーのカテゴリにアクセスするとエラーになる" do
        other_category = create(:message_category, user: create(:user))
        get edit_message_category_path(other_category)
        expect(response).to have_http_status(404)
      end
    end
  end

  describe "PATCH /message_categories/:id" do
    before { sign_in user }

    context "正常系の場合" do
      it "message_categories_path にリダイレクトされる" do
        patch message_category_path(category), params: {
          message_category: { name: "更新名", kana: "こうしんめい", icon: category.icon, icon_color: IconDefinitions::ICON_COLORS.keys.first }
        }
        expect(response).to redirect_to(message_categories_path)
      end
    end

    context "バリデーションエラーの場合" do
      it "422 を返す" do
        patch message_category_path(category), params: {
          message_category: { name: "", kana: "", icon: category.icon }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /message_categories/:id" do
    before { sign_in user }

    it "削除して message_categories_path にリダイレクトされる" do
      cat = create(:message_category, user: user)
      expect {
        delete message_category_path(cat)
      }.to change(MessageCategory, :count).by(-1)
      expect(response).to redirect_to(message_categories_path)
    end
  end

  describe "POST /message_categories/reorder" do
    context "認証済みユーザーが他ユーザーのIDを混ぜた場合" do
      it "403 が返る" do
        other_category = create(:message_category, user: create(:user))
        sign_in user
        post reorder_message_categories_path, params: { ids: [other_category.id] }
        expect(response).to have_http_status(403)
      end
    end

    context "認証済みユーザーが自分のカテゴリのみを渡した場合" do
      before { sign_in user }

      it "{ status: 'ok' } を返す" do
        cat1 = create(:message_category, user: user)
        cat2 = create(:message_category, user: user)
        post reorder_message_categories_path, params: { ids: [cat2.id, cat1.id] }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["status"]).to eq("ok")
      end
    end
  end
end
