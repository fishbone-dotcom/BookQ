FactoryBot.define do
  factory :clinic_staff do
    clinic
    user
    role { :staff }
  end
end
