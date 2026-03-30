FactoryBot.define do
  factory :message_log do
    association :user
    association :flow_item
  end
end
