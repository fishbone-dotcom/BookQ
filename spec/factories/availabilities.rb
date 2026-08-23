FactoryBot.define do
  factory :availability do
    clinic
    day_of_week { :monday }
    start_time { "09:00" }
    end_time { "17:00" }
  end
end
