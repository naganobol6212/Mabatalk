require 'rails_helper'

RSpec.describe "Users::Registrations", type: :request do
  describe "DELETE /users" do
    let(:user) { create(:user) }

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
  end
end
