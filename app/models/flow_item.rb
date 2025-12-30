class FlowItem < ApplicationRecord
  belongs_to :category
  belongs_to :user, optional: true

  validates :key,  presence: true
  validates :name, presence: true
  validates :kana, presence: true
  validates :icon, presence: true

  validates :key, uniqueness: { scope: [:category_id, :user_id] }
end
