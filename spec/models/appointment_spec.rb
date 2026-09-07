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
      expect(overlapping.errors[:base]).to include("Someone else just booked that time — please pick a different one.")
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

  describe "one active booking per patient" do
    it "rejects a new appointment when the patient already has a pending or confirmed one" do
      patient = create(:user)
      create(:appointment, patient: patient, clinic: clinic, service: service, status: :pending)

      other_clinic = create(:clinic)
      other_service = create(:service, clinic: other_clinic)
      second = build(:appointment, patient: patient, clinic: other_clinic, service: other_service,
        starts_at: 2.days.from_now.change(hour: 10, min: 0),
        ends_at: 2.days.from_now.change(hour: 10, min: 30))

      expect(second).not_to be_valid
      expect(second.errors[:base]).to include("You already have an active booking. Only one active booking is allowed per patient.")
    end

    it "allows a new appointment once the patient's previous one is cancelled" do
      patient = create(:user)
      create(:appointment, patient: patient, clinic: clinic, service: service, status: :cancelled)

      second = build(:appointment, patient: patient, clinic: clinic, service: service,
        starts_at: 2.days.from_now.change(hour: 10, min: 0),
        ends_at: 2.days.from_now.change(hour: 10, min: 30))

      expect(second).to be_valid
    end
  end

  describe "#cancel!" do
    let(:staffer) { create(:user) }

    it "sets an active appointment's status to cancelled" do
      appointment = create(:appointment, clinic: clinic, service: service, status: :pending)
      appointment.cancel!(by: staffer)
      expect(appointment.reload.status).to eq("cancelled")
    end

    it "leaves an already-completed appointment unchanged" do
      appointment = create(:appointment, clinic: clinic, service: service, status: :completed)
      appointment.cancel!(by: staffer)
      expect(appointment.reload.status).to eq("completed")
    end

    it "cancels one of a patient's two pre-existing active appointments without tripping the one-active-booking rule" do
      patient = create(:user)
      first = create(:appointment, patient: patient, clinic: clinic, service: service, status: :confirmed,
        starts_at: 1.day.from_now.change(hour: 10, min: 0), ends_at: 1.day.from_now.change(hour: 10, min: 30))
      other_clinic = create(:clinic)
      other_service = create(:service, clinic: other_clinic)
      # Bypasses validation to simulate pre-existing data that already violates the one-active-booking rule
      # (e.g. seeded before the rule existed), which is the exact scenario that exposed this bug.
      build(:appointment, patient: patient, clinic: other_clinic, service: other_service, status: :pending,
        starts_at: 2.days.from_now.change(hour: 14, min: 0), ends_at: 2.days.from_now.change(hour: 14, min: 15))
        .save!(validate: false)

      first.cancel!(by: staffer)

      expect(first.reload.status).to eq("cancelled")
    end

    it "records a cancelled audit with the given actor and reason" do
      appointment = create(:appointment, clinic: clinic, service: service, status: :pending)

      appointment.cancel!(by: staffer, reason: "Doctor unavailable")

      audit = appointment.audits.last
      expect(audit.action).to eq("cancelled")
      expect(audit.actor).to eq(staffer)
      expect(audit.reason).to eq("Doctor unavailable")
    end

    it "records no audit when cancelling an already-inactive appointment (no-op)" do
      appointment = create(:appointment, clinic: clinic, service: service, status: :completed)

      expect { appointment.cancel!(by: staffer) }.not_to change { appointment.audits.count }
    end
  end

  describe "guest bookings" do
    it "is valid with guest contact info and no patient" do
      appointment = build(:appointment, :guest, clinic: clinic, service: service)
      expect(appointment).to be_valid
    end

    it "is invalid with neither a patient nor guest contact info" do
      appointment = build(:appointment, clinic: clinic, service: service, patient: nil, guest_name: nil, guest_email: nil)
      expect(appointment).not_to be_valid
      expect(appointment.errors[:base]).to include("Please provide your name and email, or sign in.")
    end

    it "is invalid with a guest_name but no guest_email" do
      appointment = build(:appointment, clinic: clinic, service: service, patient: nil, guest_name: "Juan", guest_email: nil)
      expect(appointment).not_to be_valid
    end

    it "normalizes guest_email to a stripped, downcased value" do
      appointment = build(:appointment, :guest, clinic: clinic, service: service, guest_email: "  Guest@Example.com  ")
      appointment.valid?
      expect(appointment.guest_email).to eq("guest@example.com")
    end

    it "rejects a guest booking whose email already belongs to a registered user" do
      create(:user, email: "taken@example.com")

      appointment = build(:appointment, :guest, clinic: clinic, service: service, guest_email: "taken@example.com")

      expect(appointment).not_to be_valid
      expect(appointment.errors[:guest_email]).to include("is already registered — please log in to book.")
    end

    it "matches an existing user's email case-insensitively" do
      create(:user, email: "taken@example.com")

      appointment = build(:appointment, :guest, clinic: clinic, service: service, guest_email: "Taken@Example.com")

      expect(appointment).not_to be_valid
    end

    it "allows a guest to have active bookings at two different clinics with the same email" do
      other_clinic = create(:clinic)
      other_service = create(:service, clinic: other_clinic)
      create(:appointment, :guest, clinic: clinic, service: service, guest_email: "multi@example.com")

      second = build(:appointment, :guest, clinic: other_clinic, service: other_service, guest_email: "multi@example.com",
        starts_at: 2.days.from_now.change(hour: 10, min: 0), ends_at: 2.days.from_now.change(hour: 10, min: 30))

      expect(second).to be_valid
    end

    it "rejects a second active booking at the same clinic under the same guest email" do
      create(:appointment, :guest, clinic: clinic, service: service, guest_email: "dup@example.com")

      second = build(:appointment, :guest, clinic: clinic, service: service, guest_email: "dup@example.com",
        starts_at: 2.days.from_now.change(hour: 10, min: 0), ends_at: 2.days.from_now.change(hour: 10, min: 30))

      expect(second).not_to be_valid
      expect(second.errors[:base]).to include("You already have an active booking at this clinic with this email.")
    end

    it "allows a second booking at the same clinic once the first is cancelled" do
      create(:appointment, :guest, clinic: clinic, service: service, guest_email: "dup2@example.com", status: :cancelled)

      second = build(:appointment, :guest, clinic: clinic, service: service, guest_email: "dup2@example.com",
        starts_at: 2.days.from_now.change(hour: 10, min: 0), ends_at: 2.days.from_now.change(hour: 10, min: 30))

      expect(second).to be_valid
    end

    it "still enforces the same overlap protection as authenticated bookings" do
      create(:appointment, :guest, clinic: clinic, service: service, guest_email: "a@example.com",
        starts_at: Time.zone.parse("2026-09-01 10:00"), ends_at: Time.zone.parse("2026-09-01 10:30"))

      overlapping = build(:appointment, :guest, clinic: clinic, service: service, guest_email: "b@example.com",
        starts_at: Time.zone.parse("2026-09-01 10:15"), ends_at: Time.zone.parse("2026-09-01 10:45"))

      expect(overlapping).not_to be_valid
      expect(overlapping.errors[:base]).to include("Someone else just booked that time — please pick a different one.")
    end

    describe "#contact_name and #contact_email" do
      it "uses the patient's info when present" do
        patient = create(:user, name: "Juan Dela Cruz", email: "juan@example.com")
        appointment = build(:appointment, clinic: clinic, service: service, patient: patient)

        expect(appointment.contact_name).to eq("Juan Dela Cruz")
        expect(appointment.contact_email).to eq("juan@example.com")
      end

      it "falls back to guest info when there's no patient" do
        appointment = build(:appointment, :guest, clinic: clinic, service: service, guest_name: "Maria", guest_email: "maria@example.com")

        expect(appointment.contact_name).to eq("Maria")
        expect(appointment.contact_email).to eq("maria@example.com")
      end
    end

    describe "#guest?" do
      it "is true when there's no patient" do
        appointment = build(:appointment, :guest, clinic: clinic, service: service)
        expect(appointment.guest?).to eq(true)
      end

      it "is false once a patient is attached (claimed)" do
        appointment = build(:appointment, :guest, clinic: clinic, service: service, patient: create(:user))
        expect(appointment.guest?).to eq(false)
      end
    end
  end

  describe "audit trail" do
    it "records a created audit when audit_actor is set before save" do
      patient = create(:user)
      appointment = build(:appointment, patient: patient, clinic: clinic, service: service)
      appointment.audit_actor = patient

      appointment.save!

      audit = appointment.audits.last
      expect(audit.action).to eq("created")
      expect(audit.actor).to eq(patient)
    end

    it "records a rescheduled audit with the previous start time when starts_at changes" do
      appointment = create(:appointment, clinic: clinic, service: service,
        starts_at: 1.day.from_now.change(hour: 10, min: 0), ends_at: 1.day.from_now.change(hour: 10, min: 30))
      old_starts_at = appointment.starts_at
      staffer = create(:user)

      appointment.audit_actor = staffer
      appointment.update!(starts_at: 2.days.from_now.change(hour: 11, min: 0), ends_at: 2.days.from_now.change(hour: 11, min: 30))

      audit = appointment.audits.order(:created_at).last
      expect(audit.action).to eq("rescheduled")
      expect(audit.actor).to eq(staffer)
      expect(audit.previous_starts_at).to eq(old_starts_at)
    end

    it "does not record an audit for a notes-only update" do
      appointment = create(:appointment, clinic: clinic, service: service)

      expect { appointment.update!(notes: "left a note") }.not_to change { appointment.audits.count }
    end
  end
end
