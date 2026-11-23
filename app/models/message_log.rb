class MessageLog < ApplicationRecord
  # 送信ID の形: 8-4-4-4-12 桁の 16 進数（ブラウザの crypto.randomUUID() が作る形）
  SUBMISSION_ID_FORMAT = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

  belongs_to :user
  belongs_to :flow_item, optional: true

  validates :flow_item, presence: true, on: :create
  # 送信ID なし（今までのタップ操作）は nil のまま通す。同じ人の中で同じ ID は 1 件だけ
  validates :submission_id,
            format: { with: SUBMISSION_ID_FORMAT },
            uniqueness: { scope: :user_id },
            allow_nil: true

  before_create :capture_snapshot

  scope :for_viewer, ->(viewer) {
    where(user_id: viewer.id).order(created_at: :desc)
  }

  private

  def capture_snapshot
    self.flow_item_name              = flow_item.name
    self.flow_item_icon              = flow_item.icon
    self.flow_item_icon_color        = flow_item.icon_color
    self.message_category_name       = flow_item.message_category.name
    self.message_category_icon_color = flow_item.message_category.icon_color
  end
end
