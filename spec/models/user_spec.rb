require "rails_helper"

RSpec.describe User, type: :model do
  it "is valid with a valid email and password" do
    user = build(:user)
    expect(user).to be_valid
  end

  it "is invalid without an email" do
    user = build(:user, email: nil)
    expect(user).not_to be_valid
  end

  it "is invalid with a duplicate email" do
    create(:user, email: "taken@example.com")
    user = build(:user, email: "taken@example.com")
    expect(user).not_to be_valid
  end

  it "is invalid with a password shorter than 6 characters" do
    user = build(:user, password: "abc", password_confirmation: "abc")
    expect(user).not_to be_valid
  end

  describe "#display_name" do
    it "returns the name when present" do
      user = build(:user, name: "Dr. Juan Dela Cruz")
      expect(user.display_name).to eq("Dr. Juan Dela Cruz")
    end

    it "falls back to the email when name is blank" do
      user = build(:user, name: nil, email: "doctor@bookq.test")
      expect(user.display_name).to eq("doctor@bookq.test")
    end
  end
end
