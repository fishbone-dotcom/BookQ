require "rails_helper"

RSpec.describe "Staff navigation drawer", type: :request do
  it "hides the clinic switcher and shows the clinic name plainly for a single-clinic staffer" do
    staffer = create(:user)
    clinic = create(:clinic, name: "Solo Clinic")
    create(:clinic_staff, clinic: clinic, user: staffer, role: :owner)

    sign_in staffer
    get staff_dashboard_path

    expect(response.body).to include("Solo Clinic")
    expect(response.body).to include("Clinic Owner")
    expect(response.body).not_to include("/staff/active_clinic") # no switcher links rendered
  end

  it "shows a clinic switcher when the staffer belongs to more than one clinic" do
    staffer = create(:user)
    clinic_a = create(:clinic, name: "Clinic A")
    clinic_b = create(:clinic, name: "Clinic B")
    create(:clinic_staff, clinic: clinic_a, user: staffer)
    create(:clinic_staff, clinic: clinic_b, user: staffer)

    sign_in staffer
    get staff_dashboard_path

    expect(response.body).to include("Clinic A")
    expect(response.body).to include("Clinic B")
  end

  it "labels placeholder sections as coming soon, not as working links" do
    staffer = create(:user)
    clinic = create(:clinic)
    create(:clinic_staff, clinic: clinic, user: staffer)

    sign_in staffer
    get staff_dashboard_path

    expect(response.body).to include("Inventory")
    expect(response.body.scan("Soon").count).to eq(8) # one per not-yet-built nav item (Dashboard and Appointments are real links)
  end

  describe "PATCH /staff/active_clinic" do
    it "switches the active clinic and remembers it for later requests" do
      staffer = create(:user)
      clinic_a = create(:clinic, name: "Clinic A")
      clinic_b = create(:clinic, name: "Clinic B")
      create(:clinic_staff, clinic: clinic_a, user: staffer)
      create(:clinic_staff, clinic: clinic_b, user: staffer)

      sign_in staffer
      patch staff_active_clinic_path(clinic_id: clinic_b.id)
      expect(response).to redirect_to(staff_dashboard_path)

      get staff_dashboard_path
      expect(response.body).to include("Clinic B")
    end

    it "ignores a clinic_id the staffer doesn't belong to" do
      staffer = create(:user)
      own_clinic = create(:clinic, name: "Own Clinic")
      other_clinic = create(:clinic, name: "Other Clinic")
      create(:clinic_staff, clinic: own_clinic, user: staffer)

      sign_in staffer
      patch staff_active_clinic_path(clinic_id: other_clinic.id)

      get staff_dashboard_path
      expect(response.body).to include("Own Clinic")
    end
  end
end
