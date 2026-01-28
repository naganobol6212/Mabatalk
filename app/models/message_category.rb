class MessageCategory < ApplicationRecord
  belongs_to :user, optional: true
  has_many :flow_items, dependent: :destroy
  validates :name, :kana, :icon, presence: true
  validates :name, uniqueness: { scope: :user_id }

  scope :for_user, ->(user) {
    if user
      where(user_id: [ nil, user.id ])
    else
      where(user_id: nil)
    end
  }

  def title
    name
  end

  def ruby
    kana
  end
end
