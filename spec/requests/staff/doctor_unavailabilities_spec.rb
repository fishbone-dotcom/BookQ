require "rails_helper"

RSpec.describe "Staff::DoctorUnavailabilities new/create", type: :request do
  include ActiveJob::TestHelper

  # Fixed to a mid-morning moment so `2.hours.from_now` (used below) can
  # never cross midnight into the next calendar day — without this, the
  # suite is flaky whenever it happens to run late at night.
  around do |example|
    travel_to(Time.zone.local(2026, 1, 6, 9, 0, 0)) { example.run }
  end

  let(:clinic) { create(:clinic) }
  let(:doctor_user) { create(:user, name: "Dr. Reyes") }
  let(:doctor) { create(:clinic_staff, clinic: clinic, user: doctor_user) }

  describe "GET /staff/doctors/:doctor_id/unavailability/new" do
    it "requires authentication" do
      get new_staff_doctor_unavailability_path(doctor)
      expect(response).to redirect_to(new_user_session_path)
    end

    it "allows a plain (non-owner) clinic staff member, unlike doctors#new" do
      staffer = create(:user)
      create(:clinic_staff, clinic: clinic, user: staffer, role: :staff)

      sign_in staffer
      get new_staff_doctor_unavailability_path(doctor)

      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /staff/doctors/:doctor_id/unavailability" do
    it "cancels the doctor's active appointments in range and notifies patients" do
      owner = create(:user)
      create(:clinic_staff, clinic: clinic, user: owner, role: :owner)
      service = create(:service, clinic: clinic)
      appointment = create(:appointment, clinic: clinic, service: service, staff: doctor_user,
        starts_at: 2.hours.from_now, ends_at: 2.hours.from_now + 30.minutes)

      sign_in owner

      expect {
        perform_enqueued_jobs do
          post staff_doctor_unavailability_path(doctor), params: {
            from_date: Date.current.iso8601, to_date: Date.current.iso8601
          }
        end
      }.to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(appointment.reload.status).to eq("cancelled")
      expect(response).to redirect_to(staff_doctors_path)
      follow_redirect!
      expect(response.body).to include("Cancelled 1 appointment")
    end

    it "does not affect a different doctor's appointments" do
      owner = create(:user)
      create(:clinic_staff, clinic: clinic, user: owner, role: :owner)
      other_doctor_user = create(:user)
      create(:clinic_staff, clinic: clinic, user: other_doctor_user)
      service = create(:service, clinic: clinic)
      other_appointment = create(:appointment, clinic: clinic, service: service, staff: other_doctor_user,
        starts_at: 2.hours.from_now, ends_at: 2.hours.from_now + 30.minutes)

      sign_in owner
      post staff_doctor_unavailability_path(doctor), params: {
        from_date: Date.current.iso8601, to_date: Date.current.iso8601
      }

      expect(other_appointment.reload.status).to eq("pending")
    end

    it "404s for a doctor belonging to a different clinic" do
      owner = create(:user)
      create(:clinic_staff, clinic: clinic, user: owner, role: :owner)
      other_clinic_doctor = create(:clinic_staff)

      sign_in owner
      post staff_doctor_unavailability_path(other_clinic_doctor), params: {}

      expect(response).to have_http_status(:not_found)
    end
  end
end
