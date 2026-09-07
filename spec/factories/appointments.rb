FactoryBot.define do
  factory :appointment do
    patient factory: :user
    clinic
    service
    starts_at { 1.day.from_now.change(hour: 10, min: 0) }
    ends_at { 1.day.from_now.change(hour: 10, min: 30) }
    status { :pending }

    trait :guest do
      patient { nil }
      sequence(:guest_email) { |n| "guest#{n}@example.com" }
      guest_name { "Guest Patient" }
      guest_phone { "09171234567" }
    end
  end
end
