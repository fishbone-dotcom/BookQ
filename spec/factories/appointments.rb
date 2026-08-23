FactoryBot.define do
  factory :appointment do
    patient { nil }
    clinic { nil }
    service { nil }
    staff { nil }
    starts_at { "2026-08-23 18:51:58" }
    ends_at { "2026-08-23 18:51:58" }
    status { 1 }
    notes { "MyText" }
  end
end
