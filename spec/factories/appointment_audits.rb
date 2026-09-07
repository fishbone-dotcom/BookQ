FactoryBot.define do
  factory :appointment_audit do
    appointment
    actor factory: :user
    action { :created }
  end
end
