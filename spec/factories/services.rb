FactoryBot.define do
  factory :service do
    clinic
    sequence(:name) { |n| "Service #{n}" }
    duration_minutes { 30 }
    price { "500.00" }
  end
end
