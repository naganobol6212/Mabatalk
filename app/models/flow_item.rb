class FlowItem < ApplicationRecord
  belongs_to :category
  belongs_to :user, optional: true

  scope :for_user, ->(user) {
    if user
      where(user_id: [ nil, user.id ])
    else
      where(user_id: nil)
    end
  }
end
