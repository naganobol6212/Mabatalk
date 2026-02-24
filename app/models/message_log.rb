class MessageLog < ApplicationRecord
  belongs_to :user
  belongs_to :flow_item, optional: true

  validates :flow_item, presence: true, on: :create

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
