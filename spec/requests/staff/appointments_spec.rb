require "rails_helper"

RSpec.describe "Staff::Appointments", type: :request do
  describe "GET /staff/appointments" do
    it "requires authentication" do
      get staff_appointments_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects a user who doesn't staff any clinic" do
      sign_in create(:user, role: :patient)
      get staff_appointments_path
      expect(response).to redirect_to(root_path)
    end

    it "only shows the current clinic's appointments for the selected day" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      service = create(:service, clinic: clinic)
      date = Date.current + 3.days

      same_day = create(:appointment, clinic: clinic, service: service,
        starts_at: date.in_time_zone.change(hour: 9), ends_at: date.in_time_zone.change(hour: 9, min: 30))
      other_day = create(:appointment, clinic: clinic, service: service,
        starts_at: (date + 1.day).in_time_zone.change(hour: 9), ends_at: (date + 1.day).in_time_zone.change(hour: 9, min: 30))

      other_clinic = create(:clinic)
      other_service = create(:service, clinic: other_clinic)
      other_clinic_appointment = create(:appointment, clinic: other_clinic, service: other_service,
        starts_at: date.in_time_zone.change(hour: 9), ends_at: date.in_time_zone.change(hour: 9, min: 30))

      sign_in staffer
      get staff_appointments_path(date: date.iso8601)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(same_day.patient.display_name)
      expect(response.body).not_to include(other_day.patient.display_name)
      expect(response.body).not_to include(other_clinic_appointment.patient.display_name)
    end

    it "excludes cancelled appointments from the default (All) filter" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      service = create(:service, clinic: clinic)
      date = Date.current + 3.days

      confirmed = create(:appointment, clinic: clinic, service: service, status: :confirmed,
        starts_at: date.in_time_zone.change(hour: 9), ends_at: date.in_time_zone.change(hour: 9, min: 30))
      cancelled = create(:appointment, clinic: clinic, service: service, status: :cancelled,
        starts_at: date.in_time_zone.change(hour: 10), ends_at: date.in_time_zone.change(hour: 10, min: 30))

      sign_in staffer
      get staff_appointments_path(date: date.iso8601)

      expect(response.body).to include(confirmed.patient.display_name)
      expect(response.body).not_to include(cancelled.patient.display_name)
    end

    it "shows only cancelled appointments under the Cancelled filter" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      service = create(:service, clinic: clinic)
      date = Date.current + 3.days

      confirmed = create(:appointment, clinic: clinic, service: service, status: :confirmed,
        starts_at: date.in_time_zone.change(hour: 9), ends_at: date.in_time_zone.change(hour: 9, min: 30))
      cancelled = create(:appointment, clinic: clinic, service: service, status: :cancelled,
        starts_at: date.in_time_zone.change(hour: 10), ends_at: date.in_time_zone.change(hour: 10, min: 30))

      sign_in staffer
      get staff_appointments_path(date: date.iso8601, status: "cancelled")

      expect(response.body).to include(cancelled.patient.display_name)
      expect(response.body).not_to include(confirmed.patient.display_name)
    end

    it "filters to an exact status when Confirmed or Pending is selected" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      service = create(:service, clinic: clinic)
      date = Date.current + 3.days

      confirmed = create(:appointment, clinic: clinic, service: service, status: :confirmed,
        starts_at: date.in_time_zone.change(hour: 9), ends_at: date.in_time_zone.change(hour: 9, min: 30))
      pending = create(:appointment, clinic: clinic, service: service, status: :pending,
        starts_at: date.in_time_zone.change(hour: 10), ends_at: date.in_time_zone.change(hour: 10, min: 30))

      sign_in staffer
      get staff_appointments_path(date: date.iso8601, status: "pending")

      expect(response.body).to include(pending.patient.display_name)
      expect(response.body).not_to include(confirmed.patient.display_name)
    end
  end
end
