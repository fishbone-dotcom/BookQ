require "rails_helper"

RSpec.describe ClinicStaff, type: :model do
  it "is valid with a clinic, user, and role" do
    clinic_staff = build(:clinic_staff)
    expect(clinic_staff).to be_valid
  end

  it "does not allow the same user to be added twice to the same clinic" do
    clinic = create(:clinic)
    user = create(:user)
    create(:clinic_staff, clinic: clinic, user: user)

    duplicate = build(:clinic_staff, clinic: clinic, user: user)
    expect(duplicate).not_to be_valid
  end

  it "allows the same user to staff two different clinics" do
    user = create(:user)
    create(:clinic_staff, clinic: create(:clinic), user: user)

    other_clinic_staff = build(:clinic_staff, clinic: create(:clinic), user: user)
    expect(other_clinic_staff).to be_valid
  end
end
