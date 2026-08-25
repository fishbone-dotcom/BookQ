require "rails_helper"

RSpec.describe "Staff::Reports", type: :request do
  describe "GET /staff/reports" do
    it "requires authentication" do
      get staff_reports_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects a user who doesn't staff any clinic" do
      sign_in create(:user, role: :patient)
      get staff_reports_path
      expect(response).to redirect_to(root_path)
    end

    it "only links to implemented reports; unimplemented ones are labeled, not dead links" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)

      sign_in staffer
      get staff_reports_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('href="/staff/reports/appointments"')
      expect(response.body).to include('href="/staff/reports/patients"')
      expect(response.body).to include('href="/staff/reports/services"')
      expect(response.body).to match(/Doctors Performance.{0,200}Soon/m)
      expect(response.body).to match(/Revenue Report.{0,200}Soon/m)
      expect(response.body).to match(/Inventory Report.{0,200}Soon/m)
    end
  end

  describe "GET /staff/reports/appointments" do
    it "counts only this clinic's appointments within the selected period" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      service = create(:service, clinic: clinic)

      in_range = create(:appointment, clinic: clinic, service: service, status: :confirmed,
        starts_at: Time.current.beginning_of_month + 2.days, ends_at: Time.current.beginning_of_month + 2.days + 30.minutes)
      out_of_range = create(:appointment, clinic: clinic, service: service, status: :confirmed,
        starts_at: 2.months.ago, ends_at: 2.months.ago + 30.minutes)

      other_clinic = create(:clinic)
      other_service = create(:service, clinic: other_clinic)
      create(:appointment, clinic: other_clinic, service: other_service, status: :confirmed,
        starts_at: Time.current.beginning_of_month + 3.days, ends_at: Time.current.beginning_of_month + 3.days + 30.minutes)

      sign_in staffer
      get staff_reports_appointments_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(">1<") # total = 1 (in_range only)
      expect(in_range.starts_at.month).to eq(Time.current.month) # sanity: fixture is actually "this month"
      expect(out_of_range.starts_at.month).not_to eq(Time.current.month)
    end

    it "changes the query range when a different period is selected" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      service = create(:service, clinic: clinic)
      last_month_appt = create(:appointment, clinic: clinic, service: service, status: :confirmed,
        starts_at: 1.month.ago.beginning_of_month + 2.days, ends_at: 1.month.ago.beginning_of_month + 2.days + 30.minutes)

      sign_in staffer
      get staff_reports_appointments_path(period: "this_month")
      this_month_body = response.body

      get staff_reports_appointments_path(period: "last_month")
      last_month_body = response.body

      expect(this_month_body).not_to eq(last_month_body)
      expect(last_month_appt.starts_at.month).to eq(1.month.ago.month) # sanity
    end
  end

  describe "GET /staff/reports/patients" do
    it "counts a patient as new only when their first-ever appointment at this clinic falls in the period" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      service = create(:service, clinic: clinic)

      returning_patient = create(:user)
      create(:appointment, clinic: clinic, service: service, patient: returning_patient, status: :completed,
        starts_at: 2.months.ago, ends_at: 2.months.ago + 30.minutes)
      create(:appointment, clinic: clinic, service: service, patient: returning_patient, status: :confirmed,
        starts_at: Time.current.beginning_of_month + 1.day, ends_at: Time.current.beginning_of_month + 1.day + 30.minutes)

      new_patient = create(:user)
      create(:appointment, clinic: clinic, service: service, patient: new_patient, status: :confirmed,
        starts_at: Time.current.beginning_of_month + 3.days, ends_at: Time.current.beginning_of_month + 3.days + 30.minutes)

      sign_in staffer
      get staff_reports_patients_path

      expect(response).to have_http_status(:success)
      body = response.body
      expect(body).to match(/New Patients.*?>1</m)
      expect(body).to match(/Returning Patients.*?>1</m)
    end
  end

  describe "GET /staff/reports/services" do
    it "counts bookings per service, scoped to this clinic and period" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer)
      popular = create(:service, clinic: clinic, name: "Popular Service")
      rare = create(:service, clinic: clinic, name: "Rare Service")

      2.times do |i|
        create(:appointment, clinic: clinic, service: popular, status: :confirmed,
          starts_at: Time.current.beginning_of_month + (i + 1).days, ends_at: Time.current.beginning_of_month + (i + 1).days + 30.minutes)
      end
      create(:appointment, clinic: clinic, service: rare, status: :confirmed,
        starts_at: Time.current.beginning_of_month + 5.days, ends_at: Time.current.beginning_of_month + 5.days + 30.minutes)

      sign_in staffer
      get staff_reports_services_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Popular Service")
      expect(response.body).to include("Rare Service")
      expect(response.body.index("Popular Service")).to be < response.body.index("Rare Service") # sorted desc by count
    end
  end
end
