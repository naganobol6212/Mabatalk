FactoryBot.define do
  factory :user do
    name { Faker::Lorem.word }
    email { Faker::Internet.email  }
    password { Faker::Internet.password(min_length: 6) }
  end
end
