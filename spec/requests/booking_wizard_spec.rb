require "rails_helper"

RSpec.describe "Booking wizard", type: :request do
  let(:patient) { create(:user) }
  let(:clinic) { create(:clinic) }
  let(:service) { create(:service, clinic: clinic, duration_minutes: 30) }
  let(:staff) { create(:user, name: "Dr. Juan Dela Cruz") }

  before do
    service
    ClinicStaff.create!(clinic: clinic, user: staff, role: :staff)
    sign_in patient
  end

  it "renders the four-step wizard with the doctor step showing display names" do
    get clinic_booking_path(clinic)

    expect(response).to have_http_status(:success)
    expect(response.body).to include('data-controller="booking-wizard"')
    expect(response.body).to include('data-step="2"') # doctor step panel
    expect(response.body).to include('name="staff_id"')
    expect(response.body).to include("Dr. Juan Dela Cruz")
    expect(response.body).to include("Staff")
    expect(response.body).to include("Kahit sino")
    expect(response.body).to include('data-booking-wizard-target="progressLine"')
    expect(response.body).not_to include("blue-")
  end

  it "labels the clinic owner distinctly from staff on the doctor step" do
    owner = create(:user, name: "Dr. Maria Santos")
    ClinicStaff.create!(clinic: clinic, user: owner, role: :owner)

    get clinic_booking_path(clinic)

    expect(response.body).to include("May-ari ng Clinic")
  end

  it "shows a Total Amount row on the confirm step when the service has a price" do
    service.update!(price: 500)

    get clinic_booking_path(clinic)

    expect(response.body).to include("Total Amount")
    expect(response.body).to include("₱500.00")
  end

  it "falls back to email for a staff member without a name" do
    nameless_staff = create(:user)
    ClinicStaff.create!(clinic: clinic, user: nameless_staff, role: :staff)

    get clinic_booking_path(clinic)

    expect(response.body).to include(nameless_staff.email)
  end

  it "renders available times as radio chips (step 3) and the confirm summary targets (step 4)" do
    monday = Date.current.next_occurring(:monday)
    create(:availability, clinic: clinic, day_of_week: :monday, start_time: "09:00", end_time: "17:00")

    get clinic_booking_path(clinic, date: monday.iso8601, month: monday.strftime("%Y-%m"))

    expect(response.body).to include('name="starts_at"')
    expect(response.body).to include('booking-wizard#slotChanged')
    expect(response.body).to include('data-booking-wizard-target="summaryStaff"')
    expect(response.body).to include('data-booking-wizard-target="summaryDate"')
    expect(response.body).to include('data-booking-wizard-target="summaryTime"')
    expect(response.body).not_to include("<select")
  end
end
