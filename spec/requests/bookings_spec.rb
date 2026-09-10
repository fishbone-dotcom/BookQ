require "rails_helper"

RSpec.describe "Bookings", type: :request do
  include ActiveJob::TestHelper

  let(:patient) { create(:user) }
  let(:clinic) { create(:clinic) }
  let(:service) { create(:service, clinic: clinic, duration_minutes: 30) }
  let(:monday) { Date.current.next_occurring(:monday) }
  let(:fake_session) { Stripe::Checkout::Session.construct_from(id: "cs_test_123", url: "https://checkout.stripe.com/pay/cs_test_123") }

  before do
    create(:availability, clinic: clinic, day_of_week: :monday, start_time: "09:00", end_time: "17:00")
    sign_in patient
    allow(Stripe::Checkout::Session).to receive(:create).and_return(fake_session)
  end

  describe "POST /clinics/:clinic_id/booking" do
    it "books the appointment and redirects to Stripe Checkout when the service has a price" do
      starts_at = monday.in_time_zone.change(hour: 9, min: 0)

      expect {
        post clinic_booking_path(clinic), params: {
          service_id: service.id, date: monday.iso8601, month: monday.strftime("%Y-%m"), starts_at: starts_at.iso8601
        }
      }.to change(Appointment, :count).by(1)

      expect(response).to redirect_to(fake_session.url)
      appointment = Appointment.last
      expect(appointment.payment).to be_pending
      expect(appointment.payment.amount).to eq(service.price)
    end

    it "books the appointment immediately with no Stripe call when the service is free" do
      free_service = create(:service, clinic: clinic, duration_minutes: 30, price: nil)
      starts_at = monday.in_time_zone.change(hour: 9, min: 0)

      expect {
        post clinic_booking_path(clinic), params: {
          service_id: free_service.id, date: monday.iso8601, month: monday.strftime("%Y-%m"), starts_at: starts_at.iso8601
        }
      }.to change(Appointment, :count).by(1)

      expect(Stripe::Checkout::Session).not_to have_received(:create)
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("Your appointment is booked")
      expect(Appointment.last.payment).to be_nil
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
      expect(response.body).to include("You already have an active booking")
    end

    it "redirects back with the date preserved when no time was selected" do
      post clinic_booking_path(clinic), params: {
        service_id: service.id, date: monday.iso8601, month: monday.strftime("%Y-%m")
      }

      expect(response).to redirect_to(
        clinic_booking_path(clinic, service_id: service.id, month: monday.strftime("%Y-%m"), date: monday.iso8601)
      )
      follow_redirect!
      expect(response.body).to include("Please select a time first")
    end
  end

  describe "GET /booking/return" do
    it "marks the payment paid and lands the patient on the confirmation flash once Stripe confirms" do
      starts_at = monday.in_time_zone.change(hour: 9, min: 0)
      post clinic_booking_path(clinic), params: {
        service_id: service.id, date: monday.iso8601, month: monday.strftime("%Y-%m"), starts_at: starts_at.iso8601
      }
      payment = Appointment.last.payment
      allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(
        Stripe::Checkout::Session.construct_from(payment_status: "paid", payment_intent: "pi_123")
      )

      get booking_payment_return_path(session_id: payment.stripe_checkout_session_id)

      expect(payment.reload).to be_paid
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("Your appointment is booked")
    end
  end

  describe "guest booking (signed out)" do
    before { sign_out patient }

    describe "GET /clinics/:clinic_id/booking" do
      it "shows the booking wizard, including available slots, without requiring sign-in" do
        get clinic_booking_path(clinic), params: { service_id: service.id, date: monday.iso8601, month: monday.strftime("%Y-%m") }

        expect(response).to have_http_status(:success)
        expect(response.body).to include("9:00 AM")
        expect(response.body).to include("guest_email")
      end
    end

    describe "POST /clinics/:clinic_id/booking" do
      it "creates a guest appointment and redirects to Stripe Checkout, without mailing yet" do
        starts_at = monday.in_time_zone.change(hour: 9, min: 0)

        expect {
          expect {
            post clinic_booking_path(clinic), params: {
              service_id: service.id, date: monday.iso8601, month: monday.strftime("%Y-%m"), starts_at: starts_at.iso8601,
              guest_name: "Maria Santos", guest_email: "maria@example.com", guest_phone: "09171234567"
            }
          }.to change(Appointment, :count).by(1)
        }.not_to change { ActionMailer::Base.deliveries.count }

        appointment = Appointment.last
        expect(appointment.guest?).to eq(true)
        expect(appointment.guest_name).to eq("Maria Santos")
        expect(appointment.guest_email).to eq("maria@example.com")
        expect(appointment.payment).to be_pending
        expect(response).to redirect_to(fake_session.url)
      end

      it "sends the guest confirmation email once Stripe confirms payment via the return URL" do
        free_service = create(:service, clinic: clinic, duration_minutes: 30, price: nil)
        starts_at = monday.in_time_zone.change(hour: 9, min: 0)

        expect {
          perform_enqueued_jobs do
            post clinic_booking_path(clinic), params: {
              service_id: free_service.id, date: monday.iso8601, month: monday.strftime("%Y-%m"), starts_at: starts_at.iso8601,
              guest_name: "Maria Santos", guest_email: "maria@example.com", guest_phone: "09171234567"
            }
          end
        }.to change { ActionMailer::Base.deliveries.count }.by(1)

        appointment = Appointment.last
        redirected_token = response.location.split("/guest_appointments/").last
        expect(Appointment.find_signed(redirected_token, purpose: :guest_management)).to eq(appointment)
      end

      it "does not let a guest book when no doctor is available (per-staff scheduling opted in)" do
        doctor_user = create(:user)
        clinic_staff = create(:clinic_staff, clinic: clinic, user: doctor_user, status: :on_leave)
        create(:availability, clinic: clinic, clinic_staff: clinic_staff, day_of_week: :monday, start_time: "09:00", end_time: "17:00")
        starts_at = monday.in_time_zone.change(hour: 9, min: 0)

        expect {
          post clinic_booking_path(clinic), params: {
            service_id: service.id, date: monday.iso8601, month: monday.strftime("%Y-%m"), starts_at: starts_at.iso8601,
            guest_name: "Maria Santos", guest_email: "maria@example.com", guest_phone: "09171234567"
          }
        }.not_to change(Appointment, :count)

        follow_redirect!
        expect(response.body).to include("No doctor is available")
      end

      it "does not let a guest double-book an already-taken slot" do
        starts_at = monday.in_time_zone.change(hour: 9, min: 0)
        create(:appointment, clinic: clinic, service: service, patient: patient, starts_at: starts_at, ends_at: starts_at + 30.minutes)

        expect {
          post clinic_booking_path(clinic), params: {
            service_id: service.id, date: monday.iso8601, month: monday.strftime("%Y-%m"), starts_at: starts_at.iso8601,
            guest_name: "Maria Santos", guest_email: "maria@example.com", guest_phone: "09171234567"
          }
        }.not_to change(Appointment, :count)

        follow_redirect!
        expect(response.body).to include("Someone else just booked that time")
      end

      it "rejects a guest booking with an email that already belongs to a registered user" do
        starts_at = monday.in_time_zone.change(hour: 9, min: 0)

        expect {
          post clinic_booking_path(clinic), params: {
            service_id: service.id, date: monday.iso8601, month: monday.strftime("%Y-%m"), starts_at: starts_at.iso8601,
            guest_name: "Patient Impersonator", guest_email: patient.email, guest_phone: "09171234567"
          }
        }.not_to change(Appointment, :count)

        follow_redirect!
        expect(response.body).to include("already registered")
      end

      it "allows a guest to book at a second clinic even with an active booking at the first" do
        other_clinic = create(:clinic)
        other_service = create(:service, clinic: other_clinic, duration_minutes: 30)
        create(:availability, clinic: other_clinic, day_of_week: :monday, start_time: "09:00", end_time: "17:00")
        create(:appointment, :guest, clinic: clinic, service: service, guest_email: "multi@example.com",
          starts_at: monday.in_time_zone.change(hour: 9, min: 0), ends_at: monday.in_time_zone.change(hour: 9, min: 30))
        starts_at = monday.in_time_zone.change(hour: 11, min: 0)

        expect {
          post clinic_booking_path(other_clinic), params: {
            service_id: other_service.id, date: monday.iso8601, month: monday.strftime("%Y-%m"), starts_at: starts_at.iso8601,
            guest_name: "Multi Clinic", guest_email: "multi@example.com", guest_phone: "09171234567"
          }
        }.to change(Appointment, :count).by(1)
      end
    end
  end
end
