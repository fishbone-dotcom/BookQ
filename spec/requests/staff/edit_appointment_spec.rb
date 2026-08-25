require "rails_helper"

RSpec.describe "Staff::Appointments edit/update/cancel", type: :request do
  describe "GET /staff/appointments/:id/edit" do
    it "requires authentication" do
      appointment = create(:appointment)
      get edit_staff_appointment_path(appointment)
      expect(response).to redirect_to(new_user_session_path)
    end

    it "404s when the appointment belongs to a different clinic (no IDOR)" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)

      other_clinic = create(:clinic)
      other_appointment = create(:appointment, clinic: other_clinic)

      sign_in staffer
      get edit_staff_appointment_path(other_appointment)

      expect(response).to have_http_status(:not_found)
    end

    it "pre-fills the current service, doctor, date and notes" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      doctor = create(:user, name: "Dr. Prefill")
      create(:clinic_staff, clinic: clinic, user: doctor)
      service = create(:service, clinic: clinic, name: "Deep Cleaning")
      appointment = create(:appointment, clinic: clinic, service: service, staff: doctor, notes: "Bring old x-ray")

      sign_in staffer
      get edit_staff_appointment_path(appointment)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Deep Cleaning")
      expect(response.body).to include("Dr. Prefill")
      expect(response.body).to include("Bring old x-ray")
    end

    it "shows a read-only notice instead of the form for a cancelled appointment" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      appointment = create(:appointment, clinic: clinic, status: :cancelled)

      sign_in staffer
      get edit_staff_appointment_path(appointment)

      expect(response.body).to include("can no longer be edited")
      expect(response.body).not_to include("Save Changes")
    end
  end

  describe "PATCH /staff/appointments/:id" do
    it "reschedules the appointment using AppointmentBooking" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      service = create(:service, clinic: clinic, duration_minutes: 30)
      monday = Date.current.next_occurring(:monday)
      create(:availability, clinic: clinic, day_of_week: :monday, start_time: "09:00", end_time: "17:00")
      appointment = create(:appointment, clinic: clinic, service: service,
        starts_at: (monday - 7.days).in_time_zone.change(hour: 10), ends_at: (monday - 7.days).in_time_zone.change(hour: 10, min: 30))
      new_starts_at = monday.in_time_zone.change(hour: 11)

      sign_in staffer
      patch staff_appointment_path(appointment), params: { service_id: service.id, date: monday.iso8601, starts_at: new_starts_at.iso8601 }

      appointment.reload
      expect(appointment.starts_at).to eq(new_starts_at)
      expect(response).to redirect_to(staff_appointments_path(date: monday.iso8601))
    end

    it "does not let staff move an appointment onto another clinic's appointment" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)

      other_clinic = create(:clinic)
      other_appointment = create(:appointment, clinic: other_clinic)

      sign_in staffer
      patch staff_appointment_path(other_appointment), params: { service_id: create(:service).id, starts_at: 3.days.from_now.iso8601 }

      expect(response).to have_http_status(:not_found)
    end

    it "re-renders edit with an alert when the new slot is unavailable" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      service = create(:service, clinic: clinic, duration_minutes: 30)
      taken_time = 3.days.from_now.change(hour: 10, min: 0)

      appointment = create(:appointment, clinic: clinic, service: service,
        starts_at: 3.days.from_now.change(hour: 14), ends_at: 3.days.from_now.change(hour: 14, min: 30))
      create(:appointment, clinic: clinic, service: service, starts_at: taken_time, ends_at: taken_time + 30.minutes)

      sign_in staffer
      patch staff_appointment_path(appointment), params: { service_id: service.id, starts_at: taken_time.iso8601 }

      expect(response).to redirect_to(edit_staff_appointment_path(appointment, service_id: service.id.to_s, staff_id: nil, date: nil))
      follow_redirect!
      expect(response.body).to include("Someone else just booked that time")
    end
  end

  describe "PATCH /staff/appointments/:id/cancel" do
    it "cancels an active appointment at the staffer's clinic" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      appointment = create(:appointment, clinic: clinic, status: :confirmed)

      sign_in staffer
      patch cancel_staff_appointment_path(appointment)

      expect(appointment.reload.status).to eq("cancelled")
      expect(response).to redirect_to(staff_appointments_path(date: appointment.starts_at.to_date.iso8601))
    end

    it "404s trying to cancel another clinic's appointment (no IDOR)" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)

      other_clinic = create(:clinic)
      other_appointment = create(:appointment, clinic: other_clinic)

      sign_in staffer
      patch cancel_staff_appointment_path(other_appointment)

      expect(response).to have_http_status(:not_found)
      expect(other_appointment.reload.status).not_to eq("cancelled")
    end
  end
end
