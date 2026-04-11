require 'rails_helper'

RSpec.describe AiSummary do
  describe '#regeneratable?' do
    context '生成から1日以上経過している場合' do
      it 'true を返す' do
        ai_summary = build(:ai_summary, generated_at: 2.days.ago)
        expect(ai_summary.regeneratable?).to be true
      end
    end

    context '生成から1日経過していない場合' do
      it 'false を返す' do
        ai_summary = build(:ai_summary, generated_at: 1.hour.ago)
        expect(ai_summary.regeneratable?).to be false
      end
    end
  end

  describe '#next_regeneratable_at' do
    it '生成日時の1日後を返す' do
      generated_at = Time.zone.local(2026, 4, 10, 12, 0, 0)
      ai_summary = build(:ai_summary, generated_at: generated_at)
      expect(ai_summary.next_regeneratable_at).to eq(Time.zone.local(2026, 4, 11, 12, 0, 0))
    end
  end
end
