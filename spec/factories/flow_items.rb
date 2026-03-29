FactoryBot.define do
  factory :flow_item do
    name { Faker::Lorem.word }
    kana { Faker::Lorem.word }
    icon { IconDefinitions::FLOW_ITEM_ICONS.keys.first }
    association :message_category
  end
end
