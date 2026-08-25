require "rails_helper"

RSpec.describe "Staff::Doctors", type: :request do
  describe "GET /staff/doctors" do
    it "requires authentication" do
      get staff_doctors_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects a user who doesn't staff any clinic" do
      sign_in create(:user, role: :patient)
      get staff_doctors_path
      expect(response).to redirect_to(root_path)
    end

    it "only lists staff for the current clinic" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      colleague = create(:user, name: "Dr. Juan Dela Cruz")
      create(:clinic_staff, clinic: clinic, user: colleague)

      other_clinic = create(:clinic)
      elsewhere = create(:user, name: "Dr. Elsewhere")
      create(:clinic_staff, clinic: other_clinic, user: elsewhere)

      sign_in staffer
      get staff_doctors_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(colleague.display_name)
      expect(response.body).not_to include(elsewhere.display_name)
    end

    it "shows the status badge with the Available/On Leave color convention" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer, status: :available)
      on_leave_user = create(:user, name: "Dr. On Leave")
      create(:clinic_staff, clinic: clinic, user: on_leave_user, status: :on_leave)

      sign_in staffer
      get staff_doctors_path

      expect(response.body).to include("Available")
      expect(response.body).to include("On Leave")
      expect(response.body).to include("bg-green-50 text-green-700")
      expect(response.body).to include("bg-amber-50 text-amber-700")
    end

    it "renders each row with a searchable name attribute for the live filter" do
      staffer = create(:user, name: "Dr. Findme")
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)

      sign_in staffer
      get staff_doctors_path

      expect(response.body).to include('data-doctor-search-name="dr. findme"')
    end
  end
end
