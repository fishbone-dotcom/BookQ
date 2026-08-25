require "rails_helper"

RSpec.describe "Staff::ClinicSettings", type: :request do
  describe "GET /staff/settings/clinic" do
    it "redirects a plain staffer away, not the owner" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer, role: :staff)

      sign_in staffer
      get staff_edit_clinic_settings_path

      expect(response).to redirect_to(staff_settings_path)
    end

    it "pre-fills the current clinic's info for the owner" do
      owner = create(:user)
      clinic = create(:clinic, owner: owner, name: "Sunrise Clinic", address: "123 Main St")
      create(:clinic_staff, clinic: clinic, user: owner, role: :owner)

      sign_in owner
      get staff_edit_clinic_settings_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Sunrise Clinic")
      expect(response.body).to include("123 Main St")
    end
  end

  describe "PATCH /staff/settings/clinic" do
    it "updates the clinic's name, address and phone for the owner" do
      owner = create(:user)
      clinic = create(:clinic, owner: owner)
      create(:clinic_staff, clinic: clinic, user: owner, role: :owner)

      sign_in owner
      patch staff_clinic_settings_path, params: { clinic: { name: "New Name", address: "New Address", phone: "0917-999-8888" } }

      expect(response).to redirect_to(staff_settings_path)
      clinic.reload
      expect(clinic.name).to eq("New Name")
      expect(clinic.address).to eq("New Address")
      expect(clinic.phone).to eq("0917-999-8888")
    end

    it "does not let a plain staffer update clinic info" do
      staffer = create(:user)
      clinic = create(:clinic, name: "Original Name")
      create(:clinic_staff, clinic: clinic, user: staffer, role: :staff)

      sign_in staffer
      patch staff_clinic_settings_path, params: { clinic: { name: "Hacked Name" } }

      expect(clinic.reload.name).to eq("Original Name")
    end

    it "does not let params change the owner_id" do
      owner = create(:user)
      other_user = create(:user)
      clinic = create(:clinic, owner: owner)
      create(:clinic_staff, clinic: clinic, user: owner, role: :owner)

      sign_in owner
      patch staff_clinic_settings_path, params: { clinic: { name: "Still Mine", owner_id: other_user.id } }

      expect(clinic.reload.owner_id).to eq(owner.id)
    end
  end
end
