require 'rails_helper'

RSpec.describe FlowItem do
  describe 'バリデーションチェック' do
    it "nameがないと保存できない" do
      flow_item = build(:flow_item, name: nil)
      expect(flow_item).to be_invalid
    end

    it "kanaがないと保存できない" do
      flow_item = build(:flow_item, kana: nil)
      expect(flow_item).to be_invalid
    end

    it "iconがないと保存できない" do
      flow_item = build(:flow_item, icon: nil)
      expect(flow_item).to be_invalid
    end
  end

  describe 'スコープ' do
    it "for_user(user)はsystem共通とそのユーザーのレコードを返す" do
      user_a = create(:user)
      user_b = create(:user)
      flow_item_a = create(:flow_item, user_id: user_a.id)
      flow_item_b = create(:flow_item, user_id: user_b.id)
      system_flow_item = create(:flow_item, user: nil)
      result = FlowItem.for_user(user_a)
      expect(result).to include(flow_item_a)
      expect(result).to include(system_flow_item)
      expect(result).not_to include(flow_item_b)
    end

    it "for_user(nil)はsystem共通のみレコードを返す(ゲストユーザーのケース)" do
      user_flow_item = create(:flow_item, user: create(:user))
      system_flow_item = create(:flow_item, user: nil)
      result = FlowItem.for_user(nil)
      expect(result).to include(system_flow_item)
      expect(result).not_to include(user_flow_item)
    end
  end
end
