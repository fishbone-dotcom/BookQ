require "rails_helper"

RSpec.describe Availability, type: :model do
  it "is valid with a clinic, day, and time range" do
    availability = build(:availability)
    expect(availability).to be_valid
  end

  it "is invalid when end_time is before start_time" do
    availability = build(:availability, start_time: "17:00", end_time: "09:00")
    expect(availability).not_to be_valid
  end

  it "is invalid when end_time equals start_time" do
    availability = build(:availability, start_time: "09:00", end_time: "09:00")
    expect(availability).not_to be_valid
  end

  describe "uniqueness per clinic/staff/day" do
    let(:clinic) { create(:clinic) }

    it "rejects a second clinic-wide row for the same clinic and day" do
      create(:availability, clinic: clinic, day_of_week: :monday)
      dup = build(:availability, clinic: clinic, day_of_week: :monday)

      expect(dup).not_to be_valid
    end

    it "rejects a second row for the same staff member and day" do
      clinic_staff = create(:clinic_staff, clinic: clinic)
      create(:availability, clinic: clinic, clinic_staff: clinic_staff, day_of_week: :monday)
      dup = build(:availability, clinic: clinic, clinic_staff: clinic_staff, day_of_week: :monday)

      expect(dup).not_to be_valid
    end

    it "allows a clinic-wide row and a staff-specific row for the same clinic and day" do
      clinic_staff = create(:clinic_staff, clinic: clinic)
      create(:availability, clinic: clinic, day_of_week: :monday)
      staff_specific = build(:availability, clinic: clinic, clinic_staff: clinic_staff, day_of_week: :monday)

      expect(staff_specific).to be_valid
    end

    it "allows two different staff members to each have a row for the same clinic and day" do
      staff_a = create(:clinic_staff, clinic: clinic)
      staff_b = create(:clinic_staff, clinic: clinic)
      create(:availability, clinic: clinic, clinic_staff: staff_a, day_of_week: :monday)
      other = build(:availability, clinic: clinic, clinic_staff: staff_b, day_of_week: :monday)

      expect(other).to be_valid
    end
  end

  describe "cross-tenant guard" do
    it "is invalid when the clinic_staff belongs to a different clinic than clinic_id" do
      clinic = create(:clinic)
      other_clinic_staff = create(:clinic_staff) # belongs to its own, different clinic
      availability = build(:availability, clinic: clinic, clinic_staff: other_clinic_staff)

      expect(availability).not_to be_valid
      expect(availability.errors[:clinic_staff]).to include("must belong to the same clinic")
    end
  end
end
