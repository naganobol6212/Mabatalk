require 'rails_helper'

RSpec.describe MessageLog do
  describe 'スナップショット（capture_snapshot）' do
    let(:message_category) { create(:message_category, name: "食事", icon_color: "orange") }
    let(:flow_item) do
      create(:flow_item,
             name: "水を飲む",
             icon: "local_drink",
             icon_color: "blue",
             message_category: message_category)
    end
    let(:log) { create(:message_log, flow_item: flow_item) }

    it "flow_item_name が保存時の flow_item.name を記録する" do
      expect(log.flow_item_name).to eq("水を飲む")
    end

    it "flow_item_icon が保存時の flow_item.icon を記録する" do
      expect(log.flow_item_icon).to eq("local_drink")
    end

    it "flow_item_icon_color が保存時の flow_item.icon_color を記録する" do
      expect(log.flow_item_icon_color).to eq("blue")
    end

    it "message_category_name が保存時の message_category.name を記録する" do
      expect(log.message_category_name).to eq("食事")
    end

    it "message_category_icon_color が保存時の message_category.icon_color を記録する" do
      expect(log.message_category_icon_color).to eq("orange")
    end

    context "保存後に flow_item の name が変わっても" do
      it "log.flow_item_name は変わらない" do
        expect(log.flow_item_name).to eq("水を飲む")
        flow_item.update!(name: "ジュースを飲む")
        expect(log.reload.flow_item_name).to eq("水を飲む")
      end
    end

    context "保存後に message_category の name が変わっても" do
      it "log.message_category_name は変わらない" do
        expect(log.message_category_name).to eq("食事")
        message_category.update!(name: "飲み物")
        expect(log.reload.message_category_name).to eq("食事")
      end
    end
  end
end
