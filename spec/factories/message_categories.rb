FactoryBot.define do
  factory :message_category do
    name { Faker::Lorem.word }
    kana { Faker::Lorem.word }
    icon { IconDefinitions::CATEGORY_ICONS.keys.first }
  end
end