require 'rails_helper'

RSpec.describe "FlowItems", type: :request do
  describe "GET /message_categories/:message_category_id/flow_items/:id/edit " do
    context "認証済みユーザーが他ユーザーのリソースにアクセスした場合" do
      it "404になる" do
        user = create(:user)
        other_user = create(:user)
        other_flow_item = create(:flow_item, user: other_user)
        sign_in user
        category = other_flow_item.message_category
        get edit_message_category_flow_item_path(category, other_flow_item)
        expect(response).to have_http_status(404)
      end
    end
  end

  describe "PATCH /message_categories/:message_category_id/flow_items/:id" do
    context "認証済みユーザーが他ユーザーのリソースにアクセスした場合" do
      it "404になる" do
        user = create(:user)
        other_user = create(:user)
        other_flow_item = create(:flow_item, user: other_user)
        sign_in user
        category = other_flow_item.message_category
        patch message_category_flow_item_path(category, other_flow_item),
              params: { flow_item: { name: "changed" } }
        expect(response).to have_http_status(404)
      end
    end
  end

  describe "DELETE /message_categories/:message_category_id/flow_items/:id" do
    context "認証済みユーザーが他ユーザーのリソースにアクセスした場合" do
      it "404になる" do
        user = create(:user)
        other_user = create(:user)
        other_flow_item = create(:flow_item, user: other_user)
        sign_in user
        category = other_flow_item.message_category
        delete message_category_flow_item_path(category, other_flow_item)
        expect(response).to have_http_status(404)
      end
    end
  end

  describe "POST /message_categories/:message_category_id/flow_items/reorder" do
    context "認証済みユーザーが他ユーザーのIDを混ぜた場合" do
      it "403になる" do
        user = create(:user)
        other_user = create(:user)
        category = create(:message_category, user: user)
        other_flow_item = create(:flow_item, user: other_user)
        sign_in user
        post reorder_message_category_flow_items_path(category),
              params: { ids: [other_flow_item.id] }
        expect(response).to have_http_status(403)
      end
    end
  end
end
