FactoryBot.define do
  factory :payment do
    appointment
    clinic { appointment.clinic }
    amount { "500.00" }
    status { :pending }
    sequence(:stripe_checkout_session_id) { |n| "cs_test_#{n}" }
  end
end
