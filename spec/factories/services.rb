FactoryBot.define do
  factory :service do
    clinic { nil }
    name { "MyString" }
    duration_minutes { 1 }
    price { "9.99" }
  end
end
