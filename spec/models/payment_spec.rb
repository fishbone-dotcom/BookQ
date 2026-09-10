require "rails_helper"

RSpec.describe Payment, type: :model do
  include ActiveJob::TestHelper

  describe "validations" do
    it "requires a positive amount" do
      payment = build(:payment, amount: 0)
      expect(payment).not_to be_valid
      expect(payment.errors[:amount]).to be_present
    end

    it "requires a unique stripe_checkout_session_id" do
      existing = create(:payment)
      payment = build(:payment, stripe_checkout_session_id: existing.stripe_checkout_session_id)
      expect(payment).not_to be_valid
    end
  end

  describe "#mark_paid!" do
    it "marks the payment paid and stores the payment intent id" do
      payment = create(:payment, status: :pending)

      payment.mark_paid!(payment_intent_id: "pi_123")

      expect(payment.reload).to be_paid
      expect(payment.stripe_payment_intent_id).to eq("pi_123")
    end

    it "sends the guest confirmation mailer exactly once, even if called twice" do
      appointment = create(:appointment, :guest)
      payment = create(:payment, appointment: appointment, status: :pending)

      expect {
        perform_enqueued_jobs do
          payment.mark_paid!(payment_intent_id: "pi_123")
          payment.mark_paid!(payment_intent_id: "pi_123")
        end
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "does not mail a signed-in patient's appointment" do
      payment = create(:payment, status: :pending)

      expect {
        perform_enqueued_jobs { payment.mark_paid!(payment_intent_id: "pi_123") }
      }.not_to change { ActionMailer::Base.deliveries.count }
    end
  end

  describe "#mark_failed!" do
    it "marks the payment failed and cancels the appointment" do
      payment = create(:payment, status: :pending)

      payment.mark_failed!

      expect(payment.reload).to be_failed
      expect(payment.appointment.reload).to be_cancelled
    end

    it "does nothing once already paid" do
      payment = create(:payment, status: :paid, stripe_payment_intent_id: "pi_123")

      payment.mark_failed!

      expect(payment.reload).to be_paid
      expect(payment.appointment.reload).not_to be_cancelled
    end
  end
end
