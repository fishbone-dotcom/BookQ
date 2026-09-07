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

  describe ".from_google" do
    def auth_hash(uid: "12345", email: "newpatient@example.com", name: "New Patient")
      OmniAuth::AuthHash.new(provider: "google_oauth2", uid: uid, info: { email: email, name: name })
    end

    it "creates a new patient on first sign-in" do
      user = User.from_google(auth_hash)

      expect(user).to be_persisted
      expect(user.provider).to eq("google_oauth2")
      expect(user.uid).to eq("12345")
      expect(user.email).to eq("newpatient@example.com")
      expect(user.name).to eq("New Patient")
      expect(user).to be_patient
    end

    it "returns the same user on a second sign-in with the same provider/uid" do
      first = User.from_google(auth_hash)
      second = User.from_google(auth_hash)

      expect(second).to eq(first)
      expect(User.count).to eq(1)
    end

    it "links an existing email/password account that shares the Google email" do
      existing = create(:user, email: "existing@example.com")

      linked = User.from_google(auth_hash(email: "existing@example.com"))

      expect(linked).to eq(existing)
      expect(linked.reload.provider).to eq("google_oauth2")
      expect(linked.uid).to eq("12345")
      expect(User.count).to eq(1)
    end
  end

  describe "#claim_guest_appointments!" do
    let(:clinic) { create(:clinic) }
    let(:service) { create(:service, clinic: clinic) }

    it "attaches an unclaimed guest appointment matching the user's email" do
      guest_appointment = create(:appointment, :guest, clinic: clinic, service: service, guest_email: "juan@example.com")
      user = create(:user, email: "juan@example.com")

      user.claim_guest_appointments!

      expect(guest_appointment.reload.patient_id).to eq(user.id)
      expect(guest_appointment.guest?).to eq(false)
    end

    it "does not touch a guest appointment already claimed by someone else" do
      other_user = create(:user, email: "other@example.com")
      guest_appointment = create(:appointment, :guest, clinic: clinic, service: service, guest_email: "shared@example.com")
      guest_appointment.update_column(:patient_id, other_user.id)

      user = create(:user, email: "shared@example.com")
      user.claim_guest_appointments!

      expect(guest_appointment.reload.patient_id).to eq(other_user.id)
    end

    it "does not touch another user's guest appointments (different email)" do
      guest_appointment = create(:appointment, :guest, clinic: clinic, service: service, guest_email: "someoneelse@example.com")
      user = create(:user, email: "juan@example.com")

      user.claim_guest_appointments!

      expect(guest_appointment.reload.patient_id).to be_nil
    end

    it "skips a claim that would violate the one-active-booking-per-patient rule, without raising" do
      # Guest appointment must be created before the colliding user exists —
      # guest_email_not_registered would otherwise block it outright.
      other_clinic = create(:clinic)
      guest_appointment = create(:appointment, :guest, clinic: other_clinic, service: create(:service, clinic: other_clinic),
        guest_email: "juan@example.com")

      user = create(:user, email: "juan@example.com")
      create(:appointment, patient: user, clinic: clinic, service: service, status: :pending)

      expect { user.claim_guest_appointments! }.not_to raise_error
      expect(guest_appointment.reload.patient_id).to be_nil
    end
  end
end
