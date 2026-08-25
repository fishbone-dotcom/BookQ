require "rails_helper"

RSpec.describe "Staff::Settings", type: :request do
  describe "GET /staff/settings" do
    it "requires authentication" do
      get staff_settings_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects a user who doesn't staff any clinic" do
      sign_in create(:user, role: :patient)
      get staff_settings_path
      expect(response).to redirect_to(root_path)
    end

    it "shows Clinic Information, Working Hours and Users & Roles as real links for an owner" do
      owner = create(:user)
      clinic = create(:clinic, owner: owner)
      create(:clinic_staff, clinic: clinic, user: owner, role: :owner)

      sign_in owner
      get staff_settings_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('href="/staff/settings/clinic"')
      expect(response.body).to include('href="/staff/settings/hours"')
      expect(response.body).to include('href="/staff/clinic_staffs"')
      expect(response.body).not_to include("Owner only")
    end

    it "shows those rows as disabled 'Owner only' for a plain staffer" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer, role: :staff)

      sign_in staffer
      get staff_settings_path

      expect(response.body).not_to include('href="/staff/settings/clinic"')
      expect(response.body).not_to include('href="/staff/settings/hours"')
      expect(response.body).not_to include('href="/staff/clinic_staffs"')
      expect(response.body).to include("Owner only")
    end

    it "always shows Profile, Change Password and Logout regardless of role" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer, role: :staff)

      sign_in staffer
      get staff_settings_path

      expect(response.body).to include("Profile")
      expect(response.body).to include("Change Password")
      expect(response.body).to include("Logout")
    end
  end
end
