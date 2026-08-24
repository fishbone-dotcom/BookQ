require "rails_helper"

RSpec.describe "Staff::Dashboard", type: :request do
  describe "GET /staff/dashboard" do
    it "requires authentication" do
      get staff_dashboard_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects a user who doesn't staff any clinic" do
      sign_in create(:user, role: :patient)
      get staff_dashboard_path
      expect(response).to redirect_to(root_path)
    end

    it "shows stats and upcoming appointments scoped to the staffer's own clinic" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      service = create(:service, clinic: clinic)

      today_appointment = create(:appointment, clinic: clinic, service: service,
        starts_at: 1.hour.from_now, ends_at: 1.hour.from_now + 30.minutes)
      cancelled_appointment = create(:appointment, clinic: clinic, service: service,
        starts_at: 1.day.from_now, ends_at: 1.day.from_now + 30.minutes, status: :cancelled)

      other_clinic = create(:clinic)
      other_service = create(:service, clinic: other_clinic)
      create(:appointment, clinic: other_clinic, service: other_service, starts_at: 2.days.from_now, ends_at: 2.days.from_now + 30.minutes)

      sign_in staffer
      get staff_dashboard_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(today_appointment.patient.display_name)
      expect(response.body).not_to include(cancelled_appointment.patient.display_name)
    end

    it "does not leak another clinic's stats to a staffer without access" do
      staffer = create(:user)
      own_clinic = create(:clinic)
      create(:clinic_staff, clinic: own_clinic, user: staffer)

      other_clinic = create(:clinic)
      other_service = create(:service, clinic: other_clinic)
      other_appointment = create(:appointment, clinic: other_clinic, service: other_service, starts_at: 1.day.from_now, ends_at: 1.day.from_now + 30.minutes)

      sign_in staffer
      get staff_dashboard_path

      expect(response.body).not_to include(other_appointment.patient.display_name)
    end
  end
end
