require "rails_helper"

RSpec.describe PatientProfile, type: :model do
  describe "#age" do
    it "returns nil when there's no birthdate" do
      profile = build(:patient_profile, birthdate: nil)
      expect(profile.age).to be_nil
    end

    it "computes age from birthdate, accounting for whether the birthday has passed this year" do
      travel_to Date.new(2026, 8, 25) do
        not_yet_birthday = build(:patient_profile, birthdate: Date.new(1996, 12, 1))
        already_had_birthday = build(:patient_profile, birthdate: Date.new(1996, 1, 1))

        expect(not_yet_birthday.age).to eq(29)
        expect(already_had_birthday.age).to eq(30)
      end
    end
  end
end
