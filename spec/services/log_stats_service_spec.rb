require 'rails_helper'

RSpec.describe LogStatsService do
  describe '.call' do
    it "ログが0件のとき空のデータを返す" do
      user = create(:user)
      month = Date.new(2026, 3, 1)
      result = LogStatsService.call(user: user, month: month)
      expect(result[:chart_data]).to eq([])
      expect(result[:detail_data]).to eq({})
    end
  end
end