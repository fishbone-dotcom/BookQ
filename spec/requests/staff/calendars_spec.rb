require "rails_helper"

RSpec.describe "Staff::Calendars", type: :request do
  describe "GET /staff/calendar" do
    it "requires authentication" do
      get staff_calendar_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects a user who doesn't staff any clinic" do
      sign_in create(:user, role: :patient)
      get staff_calendar_path
      expect(response).to redirect_to(root_path)
    end

    it "shows a closed message on a day with no availability" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      sunday = Date.current.next_occurring(:sunday)

      sign_in staffer
      get staff_calendar_path(date: sunday.iso8601)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Clinic is closed")
    end

    it "renders that day's clinic-scoped appointments and the availability hour range" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      service = create(:service, clinic: clinic)
      monday = Date.current.next_occurring(:monday)
      create(:availability, clinic: clinic, day_of_week: :monday, start_time: "09:00", end_time: "12:00")

      in_range = create(:appointment, clinic: clinic, service: service,
        starts_at: monday.in_time_zone.change(hour: 10), ends_at: monday.in_time_zone.change(hour: 10, min: 30))

      other_clinic = create(:clinic)
      other_service = create(:service, clinic: other_clinic)
      other_clinic_appointment = create(:appointment, clinic: other_clinic, service: other_service,
        starts_at: monday.in_time_zone.change(hour: 10), ends_at: monday.in_time_zone.change(hour: 10, min: 30))

      sign_in staffer
      get staff_calendar_path(date: monday.iso8601)

      expect(response.body).to include(in_range.patient.display_name)
      expect(response.body).not_to include(other_clinic_appointment.patient.display_name)
      expect(response.body).to include("9 AM")
      expect(response.body).not_to include("1 PM") # outside the 9-12 availability window
    end

    it "excludes cancelled appointments" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      service = create(:service, clinic: clinic)
      monday = Date.current.next_occurring(:monday)
      create(:availability, clinic: clinic, day_of_week: :monday, start_time: "09:00", end_time: "17:00")

      cancelled = create(:appointment, clinic: clinic, service: service, status: :cancelled,
        starts_at: monday.in_time_zone.change(hour: 10), ends_at: monday.in_time_zone.change(hour: 10, min: 30))

      sign_in staffer
      get staff_calendar_path(date: monday.iso8601)

      expect(response.body).not_to include(cancelled.patient.display_name)
    end
  end
end
