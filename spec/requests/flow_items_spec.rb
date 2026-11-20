require 'rails_helper'

RSpec.describe "FlowItems", type: :request do
  let(:user) { create(:user) }
  let(:category) { create(:message_category, user: user) }
  let(:flow_item) { create(:flow_item, message_category: category, user: user) }

  let(:valid_params) do
    {
      flow_item: {
        name: "テストアイテム",
        kana: "てすとあいてむ",
        icon: IconDefinitions::FLOW_ITEM_ICONS.keys.first,
        icon_color: IconDefinitions::ICON_COLORS.keys.first
      }
    }
  end

  describe "GET /message_categories/:message_category_id/flow_items" do
    context "認証済みユーザーの場合" do
      before { sign_in user }

      it "200 OK を返す" do
        get message_category_flow_items_path(category)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /message_categories/:message_category_id/flow_items/new" do
    context "未認証ユーザーの場合" do
      it "ログインページにリダイレクトされる" do
        get new_message_category_flow_item_path(category)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みユーザーの場合" do
      before { sign_in user }

      it "200 OK を返す" do
        get new_message_category_flow_item_path(category)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /message_categories/:message_category_id/flow_items/:id/confirm" do
    it "共通項目は未認証でも 200 OK を返す" do
      shared_category = create(:message_category, user: nil)
      shared_flow_item = create(:flow_item, message_category: shared_category, user: nil)
      get confirm_message_category_flow_item_path(shared_category, shared_flow_item)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /message_categories/:message_category_id/flow_items" do
    before { sign_in user }

    context "正常系の場合" do
      it "flow_items_path にリダイレクトされる" do
        post message_category_flow_items_path(category), params: valid_params
        expect(response).to redirect_to(message_category_flow_items_path(category))
      end
    end

    context "バリデーションエラーの場合" do
      it "422 を返す" do
        post message_category_flow_items_path(category), params: {
          flow_item: { name: "", kana: "", icon: IconDefinitions::FLOW_ITEM_ICONS.keys.first }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /message_categories/:message_category_id/flow_items/:id/edit" do
    context "認証済みユーザーの場合" do
      before { sign_in user }

      it "200 OK を返す" do
        get edit_message_category_flow_item_path(category, flow_item)
        expect(response).to have_http_status(:ok)
      end

      it "他ユーザーのリソースにアクセスすると 404 になる" do
        other_flow_item = create(:flow_item, message_category: category, user: create(:user))
        get edit_message_category_flow_item_path(category, other_flow_item)
        expect(response).to have_http_status(404)
      end
    end
  end

  describe "PATCH /message_categories/:message_category_id/flow_items/:id" do
    before { sign_in user }

    context "正常系の場合" do
      it "flow_items_path にリダイレクトされる" do
        patch message_category_flow_item_path(category, flow_item), params: valid_params
        expect(response).to redirect_to(message_category_flow_items_path(category))
      end
    end

    context "バリデーションエラーの場合" do
      it "422 を返す" do
        patch message_category_flow_item_path(category, flow_item), params: {
          flow_item: { name: "", kana: "", icon: flow_item.icon }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "他ユーザーのリソースにアクセスした場合" do
      it "404 になる" do
        other_flow_item = create(:flow_item, message_category: category, user: create(:user))
        patch message_category_flow_item_path(category, other_flow_item),
              params: { flow_item: { name: "changed" } }
        expect(response).to have_http_status(404)
      end
    end
  end

  describe "DELETE /message_categories/:message_category_id/flow_items/:id" do
    before { sign_in user }

    context "正常系の場合" do
      it "削除して flow_items_path にリダイレクトされる" do
        item = create(:flow_item, message_category: category, user: user)
        expect {
          delete message_category_flow_item_path(category, item)
        }.to change(FlowItem, :count).by(-1)
        expect(response).to redirect_to(message_category_flow_items_path(category))
      end
    end

    context "他ユーザーのリソースにアクセスした場合" do
      it "404 になる" do
        other_flow_item = create(:flow_item, message_category: category, user: create(:user))
        delete message_category_flow_item_path(category, other_flow_item)
        expect(response).to have_http_status(404)
      end
    end
  end

  describe "他ユーザーのカスタムカテゴリ・項目へのアクセス制御" do
    let(:other_user) { create(:user) }
    let(:other_category) { create(:message_category, user: other_user) }
    let(:other_flow_item) { create(:flow_item, message_category: other_category, user: other_user) }
    let(:shared_category) { create(:message_category, user: nil) }
    let(:shared_flow_item) { create(:flow_item, message_category: shared_category, user: nil) }

    context "未認証ユーザーの場合" do
      it "他ユーザーのカスタムカテゴリの index は 404 になる" do
        get message_category_flow_items_path(other_category)
        expect(response).to have_http_status(404)
      end

      it "他ユーザーのカスタム項目の confirm は 404 になる" do
        get confirm_message_category_flow_item_path(other_category, other_flow_item)
        expect(response).to have_http_status(404)
      end

      it "共通カテゴリの index は 200 OK を返す" do
        get message_category_flow_items_path(shared_category)
        expect(response).to have_http_status(:ok)
      end

      it "共通項目の confirm は 200 OK を返す" do
        get confirm_message_category_flow_item_path(shared_category, shared_flow_item)
        expect(response).to have_http_status(:ok)
      end
    end

    context "認証済みユーザーの場合" do
      before { sign_in user }

      it "他ユーザーのカスタムカテゴリの index は 404 になる" do
        get message_category_flow_items_path(other_category)
        expect(response).to have_http_status(404)
      end

      it "他ユーザーのカスタム項目の confirm は 404 になる" do
        get confirm_message_category_flow_item_path(other_category, other_flow_item)
        expect(response).to have_http_status(404)
      end

      it "他ユーザーのカスタムカテゴリの new は 404 になる" do
        get new_message_category_flow_item_path(other_category)
        expect(response).to have_http_status(404)
      end

      it "他ユーザーのカスタムカテゴリには項目を作成できず 404 になる" do
        other_category
        expect {
          post message_category_flow_items_path(other_category), params: valid_params
        }.not_to change(FlowItem, :count)
        expect(response).to have_http_status(404)
      end

      it "共通カテゴリには項目を作成できる" do
        shared_category
        expect {
          post message_category_flow_items_path(shared_category), params: valid_params
        }.to change(FlowItem, :count).by(1)
        expect(response).to redirect_to(message_category_flow_items_path(shared_category))
      end

      it "自分のカスタム項目の confirm は 200 OK を返す" do
        get confirm_message_category_flow_item_path(category, flow_item)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "POST /message_categories/:message_category_id/flow_items/reorder" do
    context "認証済みユーザーが他ユーザーのIDを混ぜた場合" do
      it "403 になる" do
        own_flow_item = create(:flow_item, user: user, message_category: category)
        other_flow_item = create(:flow_item, message_category: category, user: create(:user))
        sign_in user
        post reorder_message_category_flow_items_path(category),
             params: { ids: [own_flow_item.id, other_flow_item.id] }
        expect(response).to have_http_status(403)
      end
    end

    context "認証済みユーザーが自分のアイテムのみを渡した場合" do
      before { sign_in user }

      it "{ status: 'ok' } を返す" do
        item1 = create(:flow_item, message_category: category, user: user)
        item2 = create(:flow_item, message_category: category, user: user)
        post reorder_message_category_flow_items_path(category),
             params: { ids: [item2.id, item1.id] }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["status"]).to eq("ok")
      end
    end
  end
end
