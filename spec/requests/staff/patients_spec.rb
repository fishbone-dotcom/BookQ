require "rails_helper"

RSpec.describe "Staff::Patients", type: :request do
  describe "GET /staff/patients" do
    it "requires authentication" do
      get staff_patients_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects a user who doesn't staff any clinic" do
      sign_in create(:user, role: :patient)
      get staff_patients_path
      expect(response).to redirect_to(root_path)
    end

    it "only lists patients booked with this doctor, not other clinic patients (DPA data minimization)" do
      doctor = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: doctor, role: :staff)

      my_patient = create(:user, name: "Juana Dela Cruz")
      create(:appointment, clinic: clinic, patient: my_patient, staff: doctor)

      other_doctor = create(:user)
      create(:clinic_staff, clinic: clinic, user: other_doctor, role: :staff)
      colleague_patient = create(:user, name: "Colleague's Patient")
      create(:appointment, clinic: clinic, patient: colleague_patient, staff: other_doctor)

      other_clinic = create(:clinic)
      elsewhere_patient = create(:user, name: "Elsewhere Patient")
      create(:appointment, clinic: other_clinic, patient: elsewhere_patient, staff: doctor)

      never_booked = create(:user, name: "Never Booked")

      sign_in doctor
      get staff_patients_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(my_patient.display_name)
      expect(response.body).not_to include(colleague_patient.display_name)
      expect(response.body).not_to include(elsewhere_patient.display_name)
      expect(response.body).not_to include(never_booked.display_name)
    end

    it "lets the clinic owner see every patient booked at the clinic, across all doctors" do
      owner = create(:user)
      clinic = create(:clinic, owner: owner)
      create(:clinic_staff, clinic: clinic, user: owner, role: :owner)

      doctor = create(:user)
      create(:clinic_staff, clinic: clinic, user: doctor, role: :staff)
      doctor_patient = create(:user, name: "Docs Patient")
      create(:appointment, clinic: clinic, patient: doctor_patient, staff: doctor)

      sign_in owner
      get staff_patients_path

      expect(response.body).to include(doctor_patient.display_name)
    end

    it "does not leak another clinic's patient phone numbers" do
      doctor = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: doctor, role: :staff)

      other_clinic = create(:clinic)
      elsewhere_patient = create(:user, name: "Elsewhere Patient")
      create(:appointment, clinic: other_clinic, patient: elsewhere_patient, staff: doctor)
      create(:patient_profile, user: elsewhere_patient, phone: "0917-999-9999")

      sign_in doctor
      get staff_patients_path

      expect(response.body).not_to include("0917-999-9999")
    end

    it "renders each row with a searchable name/phone attribute for the live filter" do
      doctor = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: doctor, role: :staff)

      patient = create(:user, name: "Findme Patient")
      create(:appointment, clinic: clinic, patient: patient, staff: doctor)
      create(:patient_profile, user: patient, phone: "0917-555-1234")

      sign_in doctor
      get staff_patients_path

      expect(response.body).to include('data-patient-list-search-name="findme patient 0917-555-1234"')
    end

    it "lists each booked patient only once even with multiple appointments" do
      doctor = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: doctor, role: :staff)

      patient = create(:user, name: "Repeat Patient")
      create(:appointment, clinic: clinic, patient: patient, staff: doctor,
        starts_at: 1.day.from_now.change(hour: 10), ends_at: 1.day.from_now.change(hour: 10, min: 30))
      create(:appointment, clinic: clinic, patient: patient, staff: doctor, status: :cancelled,
        starts_at: 2.days.from_now.change(hour: 10), ends_at: 2.days.from_now.change(hour: 10, min: 30))

      sign_in doctor
      get staff_patients_path

      expect(response.body.scan(patient.display_name).count).to eq(1)
    end
  end
end
