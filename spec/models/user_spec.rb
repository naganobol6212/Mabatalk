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
      before { create(:user, provider: "google_oauth2", uid: "123456", email: "test@example.com") }

      it "既存ユーザーを返す" do
        expect { User.from_omniauth(auth) }.not_to change(User, :count)
      end
    end
  end
end
