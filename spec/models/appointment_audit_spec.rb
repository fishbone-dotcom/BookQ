require "rails_helper"

RSpec.describe AppointmentAudit, type: :model do
  it "is valid with an appointment and action" do
    audit = build(:appointment_audit)
    expect(audit).to be_valid
  end

  it "is valid without an actor (defensive — system/unknown actor)" do
    audit = build(:appointment_audit, actor: nil)
    expect(audit).to be_valid
  end

  it "exposes created/rescheduled/cancelled as the action enum values" do
    expect(described_class.actions).to eq({ "created" => 0, "rescheduled" => 1, "cancelled" => 2 })
  end
end
