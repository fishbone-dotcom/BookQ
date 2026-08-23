require "rails_helper"

RSpec.describe Service, type: :model do
  it "is valid with a name, duration, and clinic" do
    service = build(:service)
    expect(service).to be_valid
  end

  it "is invalid without a name" do
    service = build(:service, name: nil)
    expect(service).not_to be_valid
  end

  it "is invalid with a zero duration" do
    service = build(:service, duration_minutes: 0)
    expect(service).not_to be_valid
  end

  it "is invalid with a negative price" do
    service = build(:service, price: -1)
    expect(service).not_to be_valid
  end

  it "allows a nil price" do
    service = build(:service, price: nil)
    expect(service).to be_valid
  end
end
