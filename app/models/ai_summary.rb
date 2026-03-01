class AiSummary < ApplicationRecord
  belongs_to :user

  validates :content, :generated_at, presence: true

  REGENERATE_INTERVAL = 1.day

  def regeneratable?
    generated_at < REGENERATE_INTERVAL.ago
  end

  def next_regeneratable_at
    generated_at + REGENERATE_INTERVAL
  end
end
