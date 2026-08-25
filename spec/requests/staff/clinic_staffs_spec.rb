require "rails_helper"

RSpec.describe "Staff::ClinicStaffs", type: :request do
  describe "GET /staff/clinic_staffs" do
    it "redirects a plain staffer away" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer, role: :staff)

      sign_in staffer
      get staff_clinic_staffs_path

      expect(response).to redirect_to(staff_settings_path)
    end

    it "lists everyone staffing the clinic for the owner" do
      owner = create(:user)
      clinic = create(:clinic, owner: owner)
      create(:clinic_staff, clinic: clinic, user: owner, role: :owner)
      colleague = create(:user, name: "Dr. Colleague")
      create(:clinic_staff, clinic: clinic, user: colleague, role: :staff)

      sign_in owner
      get staff_clinic_staffs_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(colleague.display_name)
    end
  end

  describe "PATCH /staff/clinic_staffs/:id" do
    it "lets the owner promote a staffer to owner" do
      owner = create(:user)
      clinic = create(:clinic, owner: owner)
      create(:clinic_staff, clinic: clinic, user: owner, role: :owner)
      colleague = create(:user)
      clinic_staff = create(:clinic_staff, clinic: clinic, user: colleague, role: :staff)

      sign_in owner
      patch staff_clinic_staff_path(clinic_staff), params: { role: "owner" }

      expect(clinic_staff.reload.role).to eq("owner")
    end

    it "does not let the owner change their own role" do
      owner = create(:user)
      clinic = create(:clinic, owner: owner)
      owner_staff = create(:clinic_staff, clinic: clinic, user: owner, role: :owner)

      sign_in owner
      patch staff_clinic_staff_path(owner_staff), params: { role: "staff" }

      expect(owner_staff.reload.role).to eq("owner")
    end

    it "does not let a plain staffer promote themselves to owner (authorization, not just hidden UI)" do
      staffer = create(:user)
      clinic = create(:clinic)
      clinic_staff = create(:clinic_staff, clinic: clinic, user: staffer, role: :staff)

      sign_in staffer
      patch staff_clinic_staff_path(clinic_staff), params: { role: "owner" }

      expect(clinic_staff.reload.role).to eq("staff")
      expect(response).to redirect_to(staff_settings_path)
    end
  end

  describe "DELETE /staff/clinic_staffs/:id" do
    it "lets the owner remove a staffer from the clinic" do
      owner = create(:user)
      clinic = create(:clinic, owner: owner)
      create(:clinic_staff, clinic: clinic, user: owner, role: :owner)
      colleague = create(:user)
      clinic_staff = create(:clinic_staff, clinic: clinic, user: colleague, role: :staff)

      sign_in owner
      expect {
        delete staff_clinic_staff_path(clinic_staff)
      }.to change(ClinicStaff, :count).by(-1)
    end

    it "does not let the owner remove themselves" do
      owner = create(:user)
      clinic = create(:clinic, owner: owner)
      owner_staff = create(:clinic_staff, clinic: clinic, user: owner, role: :owner)

      sign_in owner
      expect {
        delete staff_clinic_staff_path(owner_staff)
      }.not_to change(ClinicStaff, :count)
    end
  end
end
