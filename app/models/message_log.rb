class MessageLog < ApplicationRecord
  belongs_to :user
  belongs_to :flow_item

  scope :for_viewer, ->(viewer) {
    where(user_id: viewer.id).order(created_at: :desc)
  }
end
