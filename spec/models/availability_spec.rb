require "rails_helper"

RSpec.describe Availability, type: :model do
  it "is valid with a clinic, day, and time range" do
    availability = build(:availability)
    expect(availability).to be_valid
  end

  it "is invalid when end_time is before start_time" do
    availability = build(:availability, start_time: "17:00", end_time: "09:00")
    expect(availability).not_to be_valid
  end

  it "is invalid when end_time equals start_time" do
    availability = build(:availability, start_time: "09:00", end_time: "09:00")
    expect(availability).not_to be_valid
  end
end
