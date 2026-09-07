require "rails_helper"

RSpec.describe DoctorUnavailability, type: :model do
  include ActiveJob::TestHelper

  let(:clinic) { create(:clinic) }
  let(:service) { create(:service, clinic: clinic) }
  let(:doctor_user) { create(:user, name: "Dr. Reyes") }
  let(:clinic_staff) { create(:clinic_staff, clinic: clinic, user: doctor_user) }

  def build_appointment(starts_at:, staff: doctor_user, clinic: self.clinic, status: :pending)
    create(:appointment, clinic: clinic, service: service, staff: staff,
      starts_at: starts_at, ends_at: starts_at + 30.minutes, status: status)
  end

  def apply(from_date: Date.current, to_date: Date.current)
    described_class.new(clinic: clinic, clinic_staff: clinic_staff, from_date: from_date, to_date: to_date).apply!
  end

  it "cancels the doctor's active future appointments within the date range and notifies each patient" do
    affected = build_appointment(starts_at: 2.hours.from_now)

    result = nil
    expect { perform_enqueued_jobs { result = apply } }
      .to change { ActionMailer::Base.deliveries.count }.by(1)

    expect(result.cancelled_count).to eq(1)
    expect(affected.reload.status).to eq("cancelled")
  end

  it "does not touch a different doctor's appointments" do
    other_doctor = create(:user)
    other_appointment = build_appointment(starts_at: 2.hours.from_now, staff: other_doctor)

    apply

    expect(other_appointment.reload.status).to eq("pending")
  end

  it "does not touch appointments at a different clinic, even for the same user" do
    other_clinic = create(:clinic)
    other_service = create(:service, clinic: other_clinic)
    other_appointment = create(:appointment, clinic: other_clinic, service: other_service, staff: doctor_user,
      starts_at: 2.hours.from_now, ends_at: 2.hours.from_now + 30.minutes)

    apply

    expect(other_appointment.reload.status).to eq("pending")
  end

  it "does not touch appointments that already started earlier today" do
    past_appointment = build_appointment(starts_at: 1.hour.ago)

    apply

    expect(past_appointment.reload.status).to eq("pending")
  end

  it "does not touch appointments outside the given date range" do
    later_appointment = build_appointment(starts_at: 5.days.from_now)

    apply(from_date: Date.current, to_date: Date.current)

    expect(later_appointment.reload.status).to eq("pending")
  end

  it "does not touch already-cancelled appointments" do
    cancelled = build_appointment(starts_at: 2.hours.from_now, status: :cancelled)

    result = apply

    expect(result.cancelled_count).to eq(0)
    expect(cancelled.reload.status).to eq("cancelled")
  end

  it "returns a zero-count result without error when nothing is affected" do
    result = apply

    expect(result.cancelled_count).to eq(0)
  end
end
