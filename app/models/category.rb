class Category < ApplicationRecord
  has_many :flow_items, dependent: :destroy
  belongs_to :user, optional: true

  validates :key, presence: true, uniqueness: true

  scope :for_user, ->(user) {
    if user
      where(user_id: [ nil, user.id ])
    else
      where(user_id: nil)
    end
  }
end
