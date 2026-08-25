require "rails_helper"

RSpec.describe "Staff::Appointments new/create", type: :request do
  describe "GET /staff/appointments/new" do
    it "requires authentication" do
      get new_staff_appointment_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects a user who doesn't staff any clinic" do
      sign_in create(:user, role: :patient)
      get new_staff_appointment_path
      expect(response).to redirect_to(root_path)
    end

    it "only lists patient-role accounts to pick from, not staff or admin" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      patient = create(:user, role: :patient, name: "Pat Patient")
      other_staffer = create(:user, role: :staff, name: "Other Staffer")
      admin = create(:user, role: :admin, name: "Admin Account")

      sign_in staffer
      get new_staff_appointment_path

      expect(response.body).to include(patient.display_name)
      expect(response.body).not_to include(other_staffer.display_name)
      expect(response.body).not_to include(admin.display_name)
    end

    it "only offers real open slots for the chosen service and date" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      service = create(:service, clinic: clinic, duration_minutes: 30)
      monday = Date.current.next_occurring(:monday)
      create(:availability, clinic: clinic, day_of_week: :monday, start_time: "09:00", end_time: "10:00")
      taken = create(:appointment, clinic: clinic, service: service,
        starts_at: monday.in_time_zone.change(hour: 9), ends_at: monday.in_time_zone.change(hour: 9, min: 30))

      sign_in staffer
      get new_staff_appointment_path(service_id: service.id, date: monday.iso8601)

      expect(response.body).to include("9:30 AM")
      expect(response.body).not_to include("9:00 AM") # taken by `taken`
    end
  end

  describe "POST /staff/appointments" do
    it "books the appointment for the selected patient using AppointmentBooking" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      patient = create(:user, role: :patient)
      service = create(:service, clinic: clinic, duration_minutes: 30)
      monday = Date.current.next_occurring(:monday)
      create(:availability, clinic: clinic, day_of_week: :monday, start_time: "09:00", end_time: "17:00")
      starts_at = monday.in_time_zone.change(hour: 10)

      sign_in staffer

      expect {
        post staff_appointments_path, params: {
          patient_id: patient.id, service_id: service.id, date: monday.iso8601, starts_at: starts_at.iso8601, notes: "Walk-in"
        }
      }.to change(Appointment, :count).by(1)

      appointment = Appointment.last
      expect(appointment.patient).to eq(patient)
      expect(appointment.status).to eq("pending") # strong params — never settable from the form
      expect(appointment.notes).to eq("Walk-in")
      expect(response).to redirect_to(staff_appointments_path(date: monday.iso8601))
    end

    it "redirects back with an alert when no patient is selected" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      service = create(:service, clinic: clinic)

      sign_in staffer

      expect {
        post staff_appointments_path, params: { service_id: service.id, starts_at: 1.day.from_now.iso8601 }
      }.not_to change(Appointment, :count)

      expect(response).to redirect_to(new_staff_appointment_path(patient_id: nil, service_id: service.id.to_s, staff_id: nil, date: nil))
    end

    it "does not bypass the one-active-booking-per-patient rule for staff-created bookings" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      service = create(:service, clinic: clinic)
      patient = create(:user, role: :patient)
      create(:appointment, patient: patient, clinic: clinic, service: service, status: :pending)

      sign_in staffer

      expect {
        post staff_appointments_path, params: {
          patient_id: patient.id, service_id: service.id, starts_at: 2.days.from_now.iso8601
        }
      }.not_to change(Appointment, :count)

      follow_redirect!
      expect(response.body).to include("already have an active booking")
    end

    it "ignores an attempt to set status directly via params" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      patient = create(:user, role: :patient)
      service = create(:service, clinic: clinic)

      sign_in staffer
      post staff_appointments_path, params: {
        patient_id: patient.id, service_id: service.id, starts_at: 2.days.from_now.iso8601, status: "completed"
      }

      expect(Appointment.last.status).to eq("pending")
    end
  end
end
