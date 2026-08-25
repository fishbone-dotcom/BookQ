require "rails_helper"

RSpec.describe "Staff::Doctors new/create", type: :request do
  describe "GET /staff/doctors/new" do
    it "requires authentication" do
      get new_staff_doctor_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "allows a clinic owner" do
      owner = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: owner, role: :owner)

      sign_in owner
      get new_staff_doctor_path

      expect(response).to have_http_status(:success)
    end

    it "blocks a plain staff member" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer, role: :staff)

      sign_in staffer
      get new_staff_doctor_path

      expect(response).to redirect_to(staff_doctors_path)
    end
  end

  describe "POST /staff/doctors" do
    it "blocks a plain staff member from creating a doctor" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer, role: :staff)

      sign_in staffer

      expect {
        post staff_doctors_path, params: { name: "Dr. New", email: "new-doctor@example.com" }
      }.not_to change(ClinicStaff, :count)

      expect(response).to redirect_to(staff_doctors_path)
    end

    it "creates a new account and attaches it to the clinic when the email is unregistered" do
      owner = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: owner, role: :owner)

      sign_in owner

      expect {
        post staff_doctors_path, params: {
          name: "Dr. Brand New", email: "brand-new@example.com", specialization: "Cardiologist",
          phone: "0917-000-0000", status: "available"
        }
      }.to change(User, :count).by(1).and change(ClinicStaff, :count).by(1)

      new_user = User.find_by(email: "brand-new@example.com")
      expect(new_user.role).to eq("staff") # never settable from params
      expect(new_user.name).to eq("Dr. Brand New")

      membership = clinic.clinic_staffs.find_by(user: new_user)
      expect(membership.specialization).to eq("Cardiologist")
      expect(membership.phone).to eq("0917-000-0000")
      expect(membership.available?).to eq(true)
      expect(response).to redirect_to(staff_doctors_path)
    end

    it "attaches an existing account without creating a duplicate User" do
      owner = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: owner, role: :owner)
      existing = create(:user, email: "already-here@example.com", name: "Existing Doctor")

      sign_in owner

      expect {
        post staff_doctors_path, params: { name: "Ignored Name", email: "already-here@example.com" }
      }.not_to change(User, :count)

      expect(clinic.clinic_staffs.find_by(user: existing)).to be_present
      expect(existing.reload.name).to eq("Existing Doctor") # not silently renamed
    end

    it "shows a clear error and does not duplicate the membership when the doctor already staffs this clinic" do
      owner = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: owner, role: :owner)
      colleague = create(:user, email: "colleague@example.com")
      create(:clinic_staff, clinic: clinic, user: colleague)

      sign_in owner

      expect {
        post staff_doctors_path, params: { name: "Colleague", email: "colleague@example.com" }
      }.not_to change(ClinicStaff, :count)

      expect(response.body).to include("already staffs this clinic")
    end

    it "never lets the form set role or clinic ownership beyond what params explicitly control" do
      owner = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: owner, role: :owner)

      sign_in owner
      post staff_doctors_path, params: {
        name: "Dr. Sneaky", email: "sneaky@example.com", role: "admin", clinic_id: create(:clinic).id
      }

      new_user = User.find_by(email: "sneaky@example.com")
      expect(new_user.role).to eq("staff")
      expect(clinic.clinic_staffs.find_by(user: new_user)).to be_present
    end
  end
end
