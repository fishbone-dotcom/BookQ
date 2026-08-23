FactoryBot.define do
  factory :appointment do
    patient factory: :user
    clinic
    service
    starts_at { 1.day.from_now.change(hour: 10, min: 0) }
    ends_at { 1.day.from_now.change(hour: 10, min: 30) }
    status { :pending }
  end
end
