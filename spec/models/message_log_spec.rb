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

  # 送信ID: まばたき画面が「はい」のたびに 1 つ作る UUID。送り直しで同じ記録が 2 件にならないための目印。
  describe '送信ID（submission_id）' do
    let(:sid) { "0f8fad5b-d9cb-469f-a165-70867728950e" }
    let(:user) { create(:user) }

    it "UUID の形（8-4-4-4-12 桁の 16 進数）なら保存できる" do
      log = create(:message_log, user: user, submission_id: sid)
      expect(log.reload.submission_id).to eq(sid)
    end

    [
      [ "空文字", "" ],
      [ "桁が足りない", "0f8fad5b-d9cb-469f-a165-70867728950" ],
      [ "ハイフンが無い", "0f8fad5bd9cb469fa16570867728950e" ],
      [ "16 進数でない文字が混じる", "zf8fad5b-d9cb-469f-a165-70867728950e" ],
      [ "うしろに改行と余計な文字が付く", "0f8fad5b-d9cb-469f-a165-70867728950e\nx" ]
    ].each do |label, value|
      it "形がおかしい（#{label}）と保存できない" do
        log = build(:message_log, user: user, submission_id: value)
        expect(log).not_to be_valid
        expect(log.errors.of_kind?(:submission_id, :invalid)).to be(true)
      end
    end

    it "同じ人が同じ送信IDをもう一度使うと保存できない" do
      create(:message_log, user: user, submission_id: sid)
      dup = build(:message_log, user: user, submission_id: sid)
      expect(dup).not_to be_valid
      expect(dup.errors.of_kind?(:submission_id, :taken)).to be(true)
    end

    it "別の人なら同じ送信IDでも保存できる" do
      create(:message_log, user: user, submission_id: sid)
      expect { create(:message_log, user: create(:user), submission_id: sid) }.to change(MessageLog, :count).by(1)
    end

    it "送信IDが空（nil）の記録は何件でも作れる" do
      expect { 3.times { create(:message_log, user: user) } }.to change(MessageLog, :count).by(3)
      expect(user.message_logs.pluck(:submission_id)).to eq([ nil, nil, nil ])
    end

    it "検査を飛ばしても DB の一意制約が 2 件目を止める" do
      create(:message_log, user: user, submission_id: sid)
      dup = build(:message_log, user: user, submission_id: sid)
      expect { dup.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
