require "rails_helper"

RSpec.describe AppointmentCheckout do
  let(:service) { create(:service, price: "500.00") }
  let(:appointment) { create(:appointment, service: service, clinic: service.clinic) }
  let(:success_url) { "https://example.com/booking/return?session_id={CHECKOUT_SESSION_ID}" }
  let(:cancel_url) { "https://example.com/clinics/#{service.clinic_id}/booking" }

  describe ".create_for" do
    it "creates a Stripe Checkout Session in PHP for the service price and a matching pending Payment" do
      fake_session = Stripe::Checkout::Session.construct_from(id: "cs_test_123", url: "https://checkout.stripe.com/pay/cs_test_123")
      allow(Stripe::Checkout::Session).to receive(:create).and_return(fake_session)

      result = described_class.create_for(appointment, success_url: success_url, cancel_url: cancel_url)

      expect(result).to be_success
      expect(result.checkout_url).to eq(fake_session.url)

      expect(Stripe::Checkout::Session).to have_received(:create).with(
        hash_including(
          mode: "payment",
          customer_email: appointment.contact_email,
          success_url: success_url,
          cancel_url: cancel_url,
          line_items: [ hash_including(price_data: hash_including(currency: "php", unit_amount: 50_000)) ]
        )
      )

      payment = Payment.find_by!(stripe_checkout_session_id: "cs_test_123")
      expect(payment).to be_pending
      expect(payment.amount).to eq(BigDecimal("500.00"))
      expect(payment.appointment).to eq(appointment)
      expect(payment.clinic).to eq(appointment.clinic)
    end

    it "cancels the appointment and returns a failure result when Stripe errors" do
      allow(Stripe::Checkout::Session).to receive(:create).and_raise(Stripe::StripeError.new("card declined"))

      result = described_class.create_for(appointment, success_url: success_url, cancel_url: cancel_url)

      expect(result).not_to be_success
      expect(result.error).to be_present
      expect(appointment.reload).to be_cancelled
      expect(Payment.where(appointment: appointment)).to be_empty
    end
  end
end
