require "rails_helper"

RSpec.describe "Admin::Dashboard", type: :request do
  describe "GET /admin/dashboard" do
    it "requires authentication" do
      get admin_dashboard_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "blocks a signed-in non-admin user" do
      sign_in create(:user, role: :patient)
      get admin_dashboard_path
      expect(response).to redirect_to(root_path)
    end

    it "shows the dashboard to an admin, with system-wide stats and appointments" do
      admin = create(:user, role: :admin)
      clinic = create(:clinic)
      service = create(:service, clinic: clinic)
      appointment = create(:appointment, clinic: clinic, service: service, status: :confirmed)

      sign_in admin
      get admin_dashboard_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(clinic.name)
      expect(response.body).to include(appointment.patient.email)
    end
  end
end
