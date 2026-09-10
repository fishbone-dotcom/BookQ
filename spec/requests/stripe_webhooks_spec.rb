require "rails_helper"

RSpec.describe "Stripe webhooks", type: :request do
  let(:webhook_secret) { "whsec_test_secret" }

  before do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:stripe, :webhook_secret).and_return(webhook_secret)
  end

  def post_stripe_event(payload_hash)
    payload = payload_hash.to_json
    timestamp = Time.current
    signature = Stripe::Webhook::Signature.compute_signature(timestamp, payload, webhook_secret)
    header = Stripe::Webhook::Signature.generate_header(timestamp, signature)

    post "/webhooks/stripe", params: payload, headers: { "Stripe-Signature" => header, "CONTENT_TYPE" => "application/json" }
  end

  describe "checkout.session.completed" do
    it "marks the payment paid" do
      payment = create(:payment, status: :pending)

      post_stripe_event(
        id: "evt_1", type: "checkout.session.completed",
        data: { object: { id: payment.stripe_checkout_session_id, payment_intent: "pi_123" } }
      )

      expect(response).to have_http_status(:ok)
      expect(payment.reload).to be_paid
      expect(payment.stripe_payment_intent_id).to eq("pi_123")
    end
  end

  describe "checkout.session.expired" do
    it "marks the payment failed and cancels the appointment" do
      payment = create(:payment, status: :pending)

      post_stripe_event(
        id: "evt_2", type: "checkout.session.expired",
        data: { object: { id: payment.stripe_checkout_session_id } }
      )

      expect(response).to have_http_status(:ok)
      expect(payment.reload).to be_failed
      expect(payment.appointment.reload).to be_cancelled
    end
  end

  it "rejects a request with a bad signature" do
    post "/webhooks/stripe", params: { type: "checkout.session.completed" }.to_json,
      headers: { "Stripe-Signature" => "t=1,v1=bogus", "CONTENT_TYPE" => "application/json" }

    expect(response).to have_http_status(:bad_request)
  end
end
