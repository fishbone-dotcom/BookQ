require "rails_helper"

RSpec.describe "Staff::Patients show/edit/update", type: :request do
  describe "GET /staff/patients/:id" do
    it "requires authentication" do
      patient = create(:user)
      get staff_patient_path(patient)
      expect(response).to redirect_to(new_user_session_path)
    end

    it "404s for a patient who hasn't booked at this clinic (no IDOR)" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)

      other_clinic = create(:clinic)
      elsewhere_patient = create(:user)
      create(:appointment, clinic: other_clinic, patient: elsewhere_patient)

      sign_in staffer
      get staff_patient_path(elsewhere_patient)

      expect(response).to have_http_status(:not_found)
    end

    it "shows personal info on the Overview tab, with sensible fallbacks for blank fields" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)

      patient = create(:user, name: "Info Patient", email: "info-patient@example.com")
      create(:appointment, clinic: clinic, patient: patient)
      create(:patient_profile, user: patient, address: "1 Test St.", blood_type: "AB+", allergies: "Penicillin",
        emergency_contact_name: "", phone: "0917-000-0000")

      sign_in staffer
      get staff_patient_path(patient)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("info-patient@example.com")
      expect(response.body).to include("1 Test St.")
      expect(response.body).to include("AB+")
      expect(response.body).to include("Penicillin")
      expect(response.body).to include("No emergency contact on file.")
    end

    it "renders 'Not set' instead of a blank row when there's no profile yet" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)

      patient = create(:user, name: "No Profile Patient")
      create(:appointment, clinic: clinic, patient: patient)

      sign_in staffer
      get staff_patient_path(patient)

      expect(response.body).to include("Not set")
      expect(response.body).to include("None recorded")
    end

    it "scopes the Appointments tab to this clinic only" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      service = create(:service, clinic: clinic, name: "Here Service")

      other_clinic = create(:clinic)
      other_service = create(:service, clinic: other_clinic, name: "Elsewhere Service")

      patient = create(:user, name: "Multi Clinic Patient")
      create(:appointment, clinic: clinic, patient: patient, service: service)

      sign_in staffer
      get staff_patient_path(patient, tab: "appointments")

      expect(response.body).to include("Here Service")
      expect(response.body).not_to include("Elsewhere Service")
    end
  end

  describe "GET /staff/patients/:id/edit and PATCH update" do
    it "404s editing a patient who hasn't booked at this clinic (no IDOR)" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)

      other_clinic = create(:clinic)
      elsewhere_patient = create(:user)
      create(:appointment, clinic: other_clinic, patient: elsewhere_patient)

      sign_in staffer
      get edit_staff_patient_path(elsewhere_patient)

      expect(response).to have_http_status(:not_found)
    end

    it "creates a profile on first save when the patient doesn't have one yet" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      patient = create(:user)
      create(:appointment, clinic: clinic, patient: patient)

      sign_in staffer

      expect {
        patch staff_patient_path(patient), params: { patient_profile: { phone: "0917-222-3333", allergies: "Dust" } }
      }.to change(PatientProfile, :count).by(1)

      expect(response).to redirect_to(staff_patient_path(patient))
      expect(patient.reload.patient_profile.phone).to eq("0917-222-3333")
    end

    it "updates an existing profile" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      patient = create(:user)
      create(:appointment, clinic: clinic, patient: patient)
      create(:patient_profile, user: patient, address: "Old Address")

      sign_in staffer
      patch staff_patient_path(patient), params: { patient_profile: { address: "New Address" } }

      expect(patient.reload.patient_profile.address).to eq("New Address")
    end

    it "does not let the update params touch the patient's account fields (e.g. role)" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      patient = create(:user, role: :patient)
      create(:appointment, clinic: clinic, patient: patient)

      sign_in staffer
      patch staff_patient_path(patient), params: { patient_profile: { address: "Somewhere" }, role: "admin" }

      expect(patient.reload.role).to eq("patient")
    end
  end
end
