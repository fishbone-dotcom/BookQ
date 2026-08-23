require "rails_helper"

RSpec.describe Clinic, type: :model do
  it "is valid with a name and owner" do
    clinic = build(:clinic)
    expect(clinic).to be_valid
  end

  it "is invalid without a name" do
    clinic = build(:clinic, name: nil)
    expect(clinic).not_to be_valid
  end

  it "is invalid without an owner" do
    clinic = build(:clinic, owner: nil)
    expect(clinic).not_to be_valid
  end
end
