require "rails_helper"

RSpec.describe SlotFinder do
  let(:clinic) { create(:clinic) }
  let(:service) { create(:service, clinic: clinic, duration_minutes: 30) }
  let(:monday) { Date.current.next_occurring(:monday) }

  def finder(date: monday, staff: nil, exclude_appointment_id: nil)
    described_class.new(clinic: clinic, service: service, date: date, staff: staff, exclude_appointment_id: exclude_appointment_id)
  end

  describe "with no staff given (clinic-wide, and the pre-per-staff-availability behavior)" do
    it "returns no slots when the clinic has no hours for that day" do
      expect(finder.slots).to eq([])
    end

    it "generates slots across the clinic-wide hours" do
      create(:availability, clinic: clinic, day_of_week: :monday, start_time: "09:00", end_time: "10:00")

      slots = finder.slots

      expect(slots.map { |s| s.starts_at.strftime("%H:%M") }).to eq([ "09:00", "09:30" ])
      expect(slots).to all(have_attributes(available: true))
    end

    it "marks a slot unavailable when any staff member's appointment overlaps it (clinic-wide conflict)" do
      create(:availability, clinic: clinic, day_of_week: :monday, start_time: "09:00", end_time: "10:00")
      someone = create(:user)
      starts_at = monday.in_time_zone.change(hour: 9, min: 0)
      create(:appointment, clinic: clinic, service: service, staff: someone, starts_at: starts_at, ends_at: starts_at + 30.minutes)

      slots = finder.slots

      expect(slots.first.available).to eq(false)
    end

    it "ignores any per-staff override rows and behaves exactly as before per-staff availability existed" do
      create(:availability, clinic: clinic, day_of_week: :monday, start_time: "09:00", end_time: "10:00")
      clinic_staff = create(:clinic_staff, clinic: clinic)
      create(:availability, clinic: clinic, clinic_staff: clinic_staff, day_of_week: :monday, start_time: "13:00", end_time: "14:00")

      slots = finder.slots

      expect(slots.map { |s| s.starts_at.strftime("%H:%M") }).to eq([ "09:00", "09:30" ])
    end
  end

  describe "with a specific staff member" do
    let(:doctor_user) { create(:user) }
    let(:clinic_staff) { create(:clinic_staff, clinic: clinic, user: doctor_user) }

    it "uses that staff member's own hours when they have an override" do
      create(:availability, clinic: clinic, day_of_week: :monday, start_time: "09:00", end_time: "17:00")
      create(:availability, clinic: clinic, clinic_staff: clinic_staff, day_of_week: :monday, start_time: "13:00", end_time: "14:00")

      slots = finder(staff: doctor_user).slots

      expect(slots.map { |s| s.starts_at.strftime("%H:%M") }).to eq([ "13:00", "13:30" ])
    end

    it "falls back to the clinic-wide hours when the staff member has no override" do
      create(:availability, clinic: clinic, day_of_week: :monday, start_time: "09:00", end_time: "10:00")

      slots = finder(staff: doctor_user).slots

      expect(slots.map { |s| s.starts_at.strftime("%H:%M") }).to eq([ "09:00", "09:30" ])
    end

    it "does not block a slot for this staff member just because a DIFFERENT staff member is booked then" do
      create(:availability, clinic: clinic, clinic_staff: clinic_staff, day_of_week: :monday, start_time: "09:00", end_time: "10:00")
      other_doctor = create(:user)
      starts_at = monday.in_time_zone.change(hour: 9, min: 0)
      create(:appointment, clinic: clinic, service: service, staff: other_doctor, starts_at: starts_at, ends_at: starts_at + 30.minutes)

      slots = finder(staff: doctor_user).slots

      expect(slots.first.available).to eq(true)
    end

    it "does block a slot when THIS staff member is already booked then" do
      create(:availability, clinic: clinic, clinic_staff: clinic_staff, day_of_week: :monday, start_time: "09:00", end_time: "10:00")
      starts_at = monday.in_time_zone.change(hour: 9, min: 0)
      create(:appointment, clinic: clinic, service: service, staff: doctor_user, starts_at: starts_at, ends_at: starts_at + 30.minutes)

      slots = finder(staff: doctor_user).slots

      expect(slots.first.available).to eq(false)
    end
  end

  describe "#available_staff_for" do
    it "returns only staff who are both in-hours and unbooked for that slot" do
      free_doctor = create(:user)
      free_staff = create(:clinic_staff, clinic: clinic, user: free_doctor, status: :available)
      create(:availability, clinic: clinic, clinic_staff: free_staff, day_of_week: :monday, start_time: "09:00", end_time: "10:00")

      busy_doctor = create(:user)
      busy_staff = create(:clinic_staff, clinic: clinic, user: busy_doctor, status: :available)
      create(:availability, clinic: clinic, clinic_staff: busy_staff, day_of_week: :monday, start_time: "09:00", end_time: "10:00")
      starts_at = monday.in_time_zone.change(hour: 9, min: 0)
      create(:appointment, clinic: clinic, service: service, staff: busy_doctor, starts_at: starts_at, ends_at: starts_at + 30.minutes)

      closed_doctor = create(:user)
      closed_staff = create(:clinic_staff, clinic: clinic, user: closed_doctor, status: :available)
      create(:availability, clinic: clinic, clinic_staff: closed_staff, day_of_week: :monday, start_time: "13:00", end_time: "14:00")

      on_leave_doctor = create(:user)
      on_leave_staff = create(:clinic_staff, clinic: clinic, user: on_leave_doctor, status: :on_leave)
      create(:availability, clinic: clinic, clinic_staff: on_leave_staff, day_of_week: :monday, start_time: "09:00", end_time: "10:00")

      slot_start = monday.in_time_zone.change(hour: 9, min: 0)
      slot_end = slot_start + 30.minutes

      available = finder.available_staff_for(slot_start, slot_end)

      expect(available).to eq([ free_staff ])
    end
  end
end
