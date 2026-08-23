require "rails_helper"

RSpec.describe Appointment, type: :model do
  let(:clinic) { create(:clinic) }
  let(:service) { create(:service, clinic: clinic) }

  it "is valid with a patient, clinic, service, and time range" do
    appointment = build(:appointment, clinic: clinic, service: service)
    expect(appointment).to be_valid
  end

  it "is invalid when ends_at is before starts_at" do
    appointment = build(:appointment, clinic: clinic, service: service,
      starts_at: 1.day.from_now.change(hour: 10),
      ends_at: 1.day.from_now.change(hour: 9))
    expect(appointment).not_to be_valid
  end

  describe "overlap prevention" do
    it "rejects a new appointment that overlaps an existing one in the same clinic" do
      create(:appointment, clinic: clinic, service: service,
        starts_at: Time.zone.parse("2026-09-01 10:00"),
        ends_at: Time.zone.parse("2026-09-01 10:30"))

      overlapping = build(:appointment, clinic: clinic, service: service,
        starts_at: Time.zone.parse("2026-09-01 10:15"),
        ends_at: Time.zone.parse("2026-09-01 10:45"))

      expect(overlapping).not_to be_valid
      expect(overlapping.errors[:base]).to include("overlaps with an existing appointment")
    end

    it "allows a back-to-back appointment that does not overlap" do
      create(:appointment, clinic: clinic, service: service,
        starts_at: Time.zone.parse("2026-09-01 10:00"),
        ends_at: Time.zone.parse("2026-09-01 10:30"))

      back_to_back = build(:appointment, clinic: clinic, service: service,
        starts_at: Time.zone.parse("2026-09-01 10:30"),
        ends_at: Time.zone.parse("2026-09-01 11:00"))

      expect(back_to_back).to be_valid
    end

    it "ignores cancelled appointments when checking for overlap" do
      create(:appointment, clinic: clinic, service: service, status: :cancelled,
        starts_at: Time.zone.parse("2026-09-01 10:00"),
        ends_at: Time.zone.parse("2026-09-01 10:30"))

      new_appointment = build(:appointment, clinic: clinic, service: service,
        starts_at: Time.zone.parse("2026-09-01 10:15"),
        ends_at: Time.zone.parse("2026-09-01 10:45"))

      expect(new_appointment).to be_valid
    end

    it "allows overlapping times at a different clinic" do
      create(:appointment, clinic: clinic, service: service,
        starts_at: Time.zone.parse("2026-09-01 10:00"),
        ends_at: Time.zone.parse("2026-09-01 10:30"))

      other_clinic = create(:clinic)
      other_service = create(:service, clinic: other_clinic)
      elsewhere = build(:appointment, clinic: other_clinic, service: other_service,
        starts_at: Time.zone.parse("2026-09-01 10:15"),
        ends_at: Time.zone.parse("2026-09-01 10:45"))

      expect(elsewhere).to be_valid
    end

    it "allows two different staff to be booked at the same clinic at the same time" do
      staff_a = create(:user)
      staff_b = create(:user)

      create(:appointment, clinic: clinic, service: service, staff: staff_a,
        starts_at: Time.zone.parse("2026-09-01 10:00"),
        ends_at: Time.zone.parse("2026-09-01 10:30"))

      other_staff_appointment = build(:appointment, clinic: clinic, service: service, staff: staff_b,
        starts_at: Time.zone.parse("2026-09-01 10:15"),
        ends_at: Time.zone.parse("2026-09-01 10:45"))

      expect(other_staff_appointment).to be_valid
    end

    it "rejects overlapping times for the same staff member" do
      staff = create(:user)

      create(:appointment, clinic: clinic, service: service, staff: staff,
        starts_at: Time.zone.parse("2026-09-01 10:00"),
        ends_at: Time.zone.parse("2026-09-01 10:30"))

      same_staff_overlap = build(:appointment, clinic: clinic, service: service, staff: staff,
        starts_at: Time.zone.parse("2026-09-01 10:15"),
        ends_at: Time.zone.parse("2026-09-01 10:45"))

      expect(same_staff_overlap).not_to be_valid
    end
  end
end
