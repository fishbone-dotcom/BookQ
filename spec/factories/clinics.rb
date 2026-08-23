FactoryBot.define do
  factory :clinic do
    sequence(:name) { |n| "Clinic #{n}" }
    address { "123 Main St" }
    phone { "0917-000-0000" }
    owner factory: :user
  end
end
