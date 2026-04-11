FactoryBot.define do
  factory :ai_summary do
    association :user
    content { "テスト用のAI要約テキスト" }
    generated_at { Time.current }
  end
end
