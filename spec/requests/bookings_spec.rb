require "rails_helper"

RSpec.describe "Bookings", type: :request do
  let(:patient) { create(:user) }
  let(:clinic) { create(:clinic) }
  let(:service) { create(:service, clinic: clinic, duration_minutes: 30) }
  let(:monday) { Date.current.next_occurring(:monday) }

  before do
    create(:availability, clinic: clinic, day_of_week: :monday, start_time: "09:00", end_time: "17:00")
    sign_in patient
  end

  describe "POST /clinics/:clinic_id/booking" do
    it "books the appointment and redirects without the date param, so the modal stays closed" do
      starts_at = monday.in_time_zone.change(hour: 9, min: 0)

      expect {
        post clinic_booking_path(clinic), params: {
          service_id: service.id, date: monday.iso8601, month: monday.strftime("%Y-%m"), starts_at: starts_at.iso8601
        }
      }.to change(Appointment, :count).by(1)

      expect(response).to redirect_to(clinic_booking_path(clinic, service_id: service.id, month: monday.strftime("%Y-%m")))
      follow_redirect!
      expect(response.body).to include("Na-book na ang appointment mo")
    end

    it "redirects back with the date preserved when the patient already has an active booking" do
      create(:appointment, patient: patient, clinic: clinic, service: service, status: :pending)
      starts_at = monday.in_time_zone.change(hour: 9, min: 0)

      post clinic_booking_path(clinic), params: {
        service_id: service.id, date: monday.iso8601, month: monday.strftime("%Y-%m"), starts_at: starts_at.iso8601
      }

      expect(response).to redirect_to(
        clinic_booking_path(clinic, service_id: service.id, month: monday.strftime("%Y-%m"), date: monday.iso8601)
      )
      follow_redirect!
      expect(response.body).to include("May aktibo ka nang booking")
    end

    it "redirects back with the date preserved when no time was selected" do
      post clinic_booking_path(clinic), params: {
        service_id: service.id, date: monday.iso8601, month: monday.strftime("%Y-%m")
      }

      expect(response).to redirect_to(
        clinic_booking_path(clinic, service_id: service.id, month: monday.strftime("%Y-%m"), date: monday.iso8601)
      )
      follow_redirect!
      expect(response.body).to include("Pumili muna ng oras")
    end
  end
end
