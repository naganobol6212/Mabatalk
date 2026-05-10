FactoryBot.define do
  factory :feedback do
    user { nil }
    category { :request }
    body { "テスト用のご意見本文" }
  end
end
