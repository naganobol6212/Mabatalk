class FlowItem < ApplicationRecord
  belongs_to :category
  belongs_to :user, optional: true
  has_many :message_logs

  validates :name, :kana, :icon, presence: true

  before_validation :set_key, on: :create

  scope :for_user, ->(user) {
    if user
      where(user_id: [ nil, user.id ])
    else
      where(user_id: nil)
    end
  }
  private

  def set_key
    self.key ||= SecureRandom.uuid
  end
end
