FactoryBot.define do
  factory :patient_profile do
    user factory: :user
    birthdate { 30.years.ago.to_date }
    sex { "Female" }
    phone { "0917-123-4567" }
    address { "123 Mango St., Quezon City" }
    blood_type { "O+" }
    allergies { "None" }
    emergency_contact_name { "Pedro Santos" }
    emergency_contact_relationship { "Father" }
    emergency_contact_phone { "0917-111-2222" }
  end
end
