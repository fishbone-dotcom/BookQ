require "rails_helper"

RSpec.describe AppointmentMailer, type: :mailer do
  describe "#reminder" do
    let(:clinic) { create(:clinic, name: "Sunrise Clinic", address: "123 Main St") }
    let(:service) { create(:service, clinic: clinic, name: "Cleaning") }
    let(:patient) { create(:user, name: "Juan Dela Cruz", email: "juan@example.com") }
    let(:appointment) do
      create(:appointment,
        clinic: clinic,
        service: service,
        patient: patient,
        starts_at: 1.day.from_now.change(hour: 10, min: 0),
        ends_at: 1.day.from_now.change(hour: 10, min: 30))
    end
    let(:mail) { AppointmentMailer.reminder(appointment) }

    it "addresses the email to the patient" do
      expect(mail.to).to eq([ "juan@example.com" ])
    end

    it "includes the clinic and service in the subject" do
      expect(mail.subject).to eq("Reminder: your Cleaning appointment at Sunrise Clinic is tomorrow")
    end

    it "includes the appointment details in the body" do
      expect(mail.body.encoded).to include("Sunrise Clinic")
      expect(mail.body.encoded).to include("Cleaning")
      expect(mail.body.encoded).to include("123 Main St")
    end

    context "when a staff member is assigned" do
      let(:staff_member) { create(:user, name: "Dr. Reyes") }

      before { appointment.update!(staff: staff_member) }

      it "includes the staff member's name" do
        expect(mail.body.encoded).to include("Dr. Reyes")
      end
    end
  end

  describe "#staff_unavailable" do
    let(:clinic) { create(:clinic, name: "Sunrise Clinic", address: "123 Main St") }
    let(:service) { create(:service, clinic: clinic, name: "Cleaning") }
    let(:patient) { create(:user, name: "Juan Dela Cruz", email: "juan@example.com") }
    let(:staff_member) { create(:user, name: "Dr. Reyes") }
    let(:appointment) do
      create(:appointment,
        clinic: clinic,
        service: service,
        patient: patient,
        staff: staff_member,
        starts_at: 1.day.from_now.change(hour: 10, min: 0),
        ends_at: 1.day.from_now.change(hour: 10, min: 30))
    end
    let(:mail) { AppointmentMailer.staff_unavailable(appointment) }

    it "addresses the email to the patient" do
      expect(mail.to).to eq([ "juan@example.com" ])
    end

    it "includes the clinic and service in the subject" do
      expect(mail.subject).to eq("Your Cleaning appointment at Sunrise Clinic has been cancelled")
    end

    it "includes the appointment and staff details, and a rebook link, in the body" do
      expect(mail.body.encoded).to include("Sunrise Clinic")
      expect(mail.body.encoded).to include("Cleaning")
      expect(mail.body.encoded).to include("123 Main St")
      expect(mail.body.encoded).to include("Dr. Reyes")
      expect(mail.body.encoded).to include(Rails.application.routes.url_helpers.clinic_booking_path(clinic))
    end
  end
end
