class MessageCategory < ApplicationRecord
  belongs_to :user

  validates :name, :kana, :icon, presence: true
  validates :name, uniqueness: { scope: user_id }
end
