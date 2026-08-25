require "rails_helper"

RSpec.describe "Staff::Availabilities", type: :request do
  describe "GET /staff/settings/hours" do
    it "redirects a plain staffer away" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer, role: :staff)

      sign_in staffer
      get staff_availabilities_path

      expect(response).to redirect_to(staff_settings_path)
    end

    it "shows the owner all 7 days with existing hours pre-filled" do
      owner = create(:user)
      clinic = create(:clinic, owner: owner)
      create(:clinic_staff, clinic: clinic, user: owner, role: :owner)
      create(:availability, clinic: clinic, day_of_week: :monday, start_time: "08:00", end_time: "16:00")

      sign_in owner
      get staff_availabilities_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Monday")
      expect(response.body).to include("Sunday")
      expect(response.body).to include("08:00")
    end
  end

  describe "PATCH /staff/settings/hours" do
    it "creates availability for a newly-opened day" do
      owner = create(:user)
      clinic = create(:clinic, owner: owner)
      create(:clinic_staff, clinic: clinic, user: owner, role: :owner)

      sign_in owner
      expect {
        patch staff_availabilities_path, params: { availabilities: { tuesday: { open: "1", start_time: "10:00", end_time: "18:00" } } }
      }.to change { clinic.availabilities.count }.by(1)

      availability = clinic.availabilities.find_by(day_of_week: :tuesday)
      expect(availability.start_time.strftime("%H:%M")).to eq("10:00")
      expect(availability.end_time.strftime("%H:%M")).to eq("18:00")
    end

    it "removes availability for a day that's unchecked" do
      owner = create(:user)
      clinic = create(:clinic, owner: owner)
      create(:clinic_staff, clinic: clinic, user: owner, role: :owner)
      create(:availability, clinic: clinic, day_of_week: :wednesday)

      sign_in owner
      patch staff_availabilities_path, params: { availabilities: { wednesday: { open: "0" } } }

      expect(clinic.availabilities.find_by(day_of_week: :wednesday)).to be_nil
    end

    it "rejects end time before start time, same as the model validation" do
      owner = create(:user)
      clinic = create(:clinic, owner: owner)
      create(:clinic_staff, clinic: clinic, user: owner, role: :owner)

      sign_in owner
      patch staff_availabilities_path, params: { availabilities: { thursday: { open: "1", start_time: "17:00", end_time: "09:00" } } }

      follow_redirect!
      expect(response.body).to include("must be after start time")
      expect(clinic.availabilities.find_by(day_of_week: :thursday)).to be_nil
    end

    it "does not let a plain staffer update working hours" do
      staffer = create(:user)
      clinic = create(:clinic)
      create(:clinic_staff, clinic: clinic, user: staffer, role: :staff)

      sign_in staffer
      expect {
        patch staff_availabilities_path, params: { availabilities: { friday: { open: "1", start_time: "09:00", end_time: "17:00" } } }
      }.not_to change(Availability, :count)
    end
  end
end
