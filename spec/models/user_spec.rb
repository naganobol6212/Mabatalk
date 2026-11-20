require 'rails_helper'

RSpec.describe User do
  describe ".from_omniauth" do
    let(:auth) do
      OmniAuth::AuthHash.new(
        provider: "google_oauth2",
        uid: "123456",
        info: {
          name: "テストユーザー",
          email: "test@example.com"
        }
      )
    end

    context "該当ユーザーが存在しない場合" do
      it "新規ユーザーを作成する" do
        expect { User.from_omniauth(auth) }.to change(User, :count).by(1)
      end

      it "auth の情報でユーザーが作成される" do
        user = User.from_omniauth(auth)
        expect(user.name).to eq("テストユーザー")
        expect(user.email).to eq("test@example.com")
        expect(user.provider).to eq("google_oauth2")
        expect(user.uid).to eq("123456")
      end
    end

    context "該当ユーザーがすでに存在する場合" do
      let!(:existing_user) { create(:user, provider: "google_oauth2", uid: "123456", email: "test@example.com") }

      it "既存ユーザーを返す" do
        returned_user = nil
        expect { returned_user = User.from_omniauth(auth) }.not_to change(User, :count)
        expect(returned_user).to eq(existing_user)
      end
    end
  end

  describe "退会（destroy）" do
    let(:user) { create(:user) }

    it "ご意見を送信済みでも削除でき、ご意見は user_id が nil になって残る" do
      feedback = create(:feedback, user: user)

      expect { user.destroy! }.to change(User, :count).by(-1)
      expect(feedback.reload.user_id).to be_nil
    end

    it "共通カテゴリに自作の項目があっても削除でき、自作の項目は削除される" do
      shared_category = create(:message_category, user: nil)
      shared_item = create(:flow_item, message_category: shared_category, user: nil)
      own_item = create(:flow_item, message_category: shared_category, user: user)

      expect { user.destroy! }.to change(User, :count).by(-1)
      expect(FlowItem.exists?(own_item.id)).to be(false)
      expect(FlowItem.exists?(shared_item.id)).to be(true)
      expect(MessageCategory.exists?(shared_category.id)).to be(true)
    end
  end
end
