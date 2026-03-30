require 'rails_helper'

RSpec.describe LogStatsService do
  describe '.call' do
    it "ログが0件のとき空のデータを返す" do
      user = create(:user)
      month = Time.zone.local(2026, 3, 1, 12, 0, 0)
      result = LogStatsService.call(user: user, month: month)
      expect(result[:chart_data]).to eq([])
      expect(result[:detail_data]).to eq({})
    end

    it "ログがあるとき集計結果を正しく返す" do
      user = create(:user)
      month = Time.zone.local(2026, 3, 1, 12, 0, 0)
      create(:message_log, user: user, created_at: month)
      result = LogStatsService.call(user: user, month: month)
      expect(result[:chart_data]).not_to be_empty
      expect(result[:detail_data]).not_to be_empty
    end

    it "指定した月以外のログを含まない" do
      user = create(:user)
      month = Time.zone.local(2026, 3, 1, 12, 0, 0)
      create(:message_log, user: user, created_at: month)
      create(:message_log, user: user, created_at: Time.zone.local(2026, 4, 1, 12, 0, 0))
      result = LogStatsService.call(user: user, month: month)
      expect(result[:chart_data].size).to eq(1)
      expect(result[:detail_data].size).to eq(1)
    end
  end
end
