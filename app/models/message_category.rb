class MessageCategory < ApplicationRecord
  belongs_to :user

  validates :name, :kana, :icon, :color, presence: true
  validates :name, uniqueness: { scope: :user_id }

  def title
    name
  end

  def ruby
    kana
  end

end
