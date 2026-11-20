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

    context "月の境界のログ" do
      let(:user) { create(:user) }
      let(:month) { Date.new(2026, 3, 1) }

      def total_count(result)
        result[:chart_data].sum { |row| row[:count] }
      end

      it "月末日の日中のログを含む" do
        create(:message_log, user: user, created_at: Time.zone.local(2026, 3, 31, 12, 0, 0))
        expect(total_count(LogStatsService.call(user: user, month: month))).to eq(1)
      end

      it "月末日の 23:59:59 のログを含む" do
        create(:message_log, user: user, created_at: Time.zone.local(2026, 3, 31, 23, 59, 59))
        expect(total_count(LogStatsService.call(user: user, month: month))).to eq(1)
      end

      it "月初日の 0:00 のログを含む" do
        create(:message_log, user: user, created_at: Time.zone.local(2026, 3, 1, 0, 0, 0))
        expect(total_count(LogStatsService.call(user: user, month: month))).to eq(1)
      end

      it "前月末日の 23:59:59 と翌月初日の 0:00 のログを含まない" do
        create(:message_log, user: user, created_at: Time.zone.local(2026, 2, 28, 23, 59, 59))
        create(:message_log, user: user, created_at: Time.zone.local(2026, 4, 1, 0, 0, 0))
        expect(total_count(LogStatsService.call(user: user, month: month))).to eq(0)
      end
    end
  end
end
