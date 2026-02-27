class FlowItem < ApplicationRecord
  belongs_to :message_category
  belongs_to :user, optional: true
  has_many :message_logs, dependent: :nullify

  validates :key, presence: true, uniqueness: true
  validates :name, :kana, :icon, presence: true
  validates :icon, inclusion: { in: ->(_) { IconDefinitions::FLOW_ITEM_ICONS.keys } }
  validates :icon_color, inclusion: { in: ->(_) { IconDefinitions::ICON_COLORS.keys } }, if: :user_id?

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
