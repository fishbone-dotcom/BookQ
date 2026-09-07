require "rails_helper"

RSpec.describe "Guest appointment management", type: :request do
  let(:clinic) { create(:clinic, name: "Sunrise Clinic") }
  let(:service) { create(:service, clinic: clinic, name: "Cleaning") }
  let(:appointment) do
    create(:appointment, :guest, clinic: clinic, service: service, guest_name: "Maria Santos", guest_email: "maria@example.com",
      starts_at: 1.day.from_now.change(hour: 10, min: 0), ends_at: 1.day.from_now.change(hour: 10, min: 30))
  end
  let(:token) { appointment.signed_id(purpose: :guest_management, expires_in: 60.days) }

  describe "GET /guest_appointments/:token" do
    it "shows the appointment details for a valid token" do
      get guest_appointment_path(token)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Sunrise Clinic")
      expect(response.body).to include("Cleaning")
    end

    it "404s for an invalid token" do
      get guest_appointment_path("not-a-real-token")

      expect(response).to have_http_status(:not_found)
    end

    it "404s for a token generated with a different purpose" do
      wrong_purpose_token = appointment.signed_id(purpose: :something_else, expires_in: 60.days)

      get guest_appointment_path(wrong_purpose_token)

      expect(response).to have_http_status(:not_found)
    end

    it "a token only ever shows its own appointment, never another guest's" do
      other_service = create(:service, clinic: clinic, name: "X-Ray")
      other_appointment = create(:appointment, :guest, clinic: clinic, service: other_service, guest_email: "someone-else@example.com",
        starts_at: 2.days.from_now.change(hour: 14, min: 0), ends_at: 2.days.from_now.change(hour: 14, min: 30))
      other_token = other_appointment.signed_id(purpose: :guest_management, expires_in: 60.days)

      get guest_appointment_path(token)
      expect(response.body).to include("Cleaning")
      expect(response.body).not_to include("X-Ray")

      get guest_appointment_path(other_token)
      expect(response.body).to include("X-Ray")
      expect(response.body).not_to include("Cleaning")
    end

    it "404s for a signed_id belonging to a non-guest (authenticated) appointment" do
      patient_appointment = create(:appointment, clinic: clinic, service: service, patient: create(:user))
      bogus_token = patient_appointment.signed_id(purpose: :guest_management, expires_in: 60.days)

      get guest_appointment_path(bogus_token)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /guest_appointments/:token/cancel" do
    it "cancels the appointment" do
      patch cancel_guest_appointment_path(token)

      expect(appointment.reload.status).to eq("cancelled")
      expect(response).to redirect_to(guest_appointment_path(token))
    end

    it "404s for an invalid token instead of cancelling anything" do
      patch cancel_guest_appointment_path("not-a-real-token")

      expect(response).to have_http_status(:not_found)
      expect(appointment.reload.status).not_to eq("cancelled")
    end
  end
end
