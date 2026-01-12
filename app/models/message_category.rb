class MessageCategory < ApplicationRecord
  belongs_to :user

  validates :name, :kana, :icon, presence: true
end
