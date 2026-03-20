require 'rails_helper'

RSpec.describe MessageCategory do
  describe 'バリデーションチェック' do
    it "nameがないと保存できない" do
      message_category = build(:message_category, name: nil)
      expect(message_category).to be_invalid
    end

    it "kanaがないと保存できない" do
      message_category = build(:message_category, kana: nil)
      expect(message_category).to be_invalid
    end

    it "iconがないと保存できない" do
      message_category = build(:message_category, icon: nil)
      expect(message_category).to be_invalid
    end
  end

  describe 'スコープ' do
    it "for_user(user)はsystem共通とそのユーザーのレコードを返す" do
      user_a = create(:user)
      user_b = create(:user)
      message_category_a = create(:message_category, user_id: user_a.id)
      message_category_b = create(:message_category, user_id: user_b.id)
      system_category = create(:message_category, user_id: nil)
      result = MessageCategory.for_user(user_a)
      expect(result).to include(message_category_a)
      expect(result).to include(system_category)
      expect(result).not_to include(message_category_b)
    end
  end
end
