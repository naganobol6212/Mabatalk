class User < ApplicationRecord
  has_one :ai_summary, dependent: :destroy
  has_many :message_logs, dependent: :destroy
  has_many :message_categories, dependent: :destroy
  validates :name, presence: true
  validates :password,
            format: { with: /\A\S+\z/, message: :no_whitespace },
            allow_nil: true

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
          :recoverable, :rememberable, :validatable,
          :omniauthable, omniauth_providers: [ :google_oauth2 ]

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.name = auth.info.name || auth.info.nickname
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 20]
    end
  end
end
