require "rails_helper"

RSpec.describe "Appointments", type: :request do
  describe "PATCH /appointments/:id/cancel" do
    it "cancels the current user's own active appointment" do
      patient = create(:user)
      clinic = create(:clinic)
      service = create(:service, clinic: clinic)
      appointment = create(:appointment, patient: patient, clinic: clinic, service: service, status: :confirmed)

      sign_in patient
      patch cancel_appointment_path(appointment)

      expect(appointment.reload.status).to eq("cancelled")
      expect(response).to redirect_to(clinic_booking_path(clinic, service_id: service.id))
    end

    it "does not let a patient cancel another patient's appointment" do
      owner = create(:user)
      other_patient = create(:user)
      clinic = create(:clinic)
      service = create(:service, clinic: clinic)
      appointment = create(:appointment, patient: other_patient, clinic: clinic, service: service, status: :confirmed)

      sign_in owner
      patch cancel_appointment_path(appointment)

      expect(response).to have_http_status(:not_found)
      expect(appointment.reload.status).to eq("confirmed")
    end

    it "requires authentication" do
      clinic = create(:clinic)
      service = create(:service, clinic: clinic)
      appointment = create(:appointment, clinic: clinic, service: service, status: :confirmed)

      patch cancel_appointment_path(appointment)

      expect(response).to redirect_to(new_user_session_path)
      expect(appointment.reload.status).to eq("confirmed")
    end
  end
end
