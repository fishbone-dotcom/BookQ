class StripeWebhooksController < ActionController::Base
  def create
    event = Stripe::Webhook.construct_event(
      request.body.read, request.headers["Stripe-Signature"],
      Rails.application.credentials.dig(:stripe, :webhook_secret))

    case event.type
    when "checkout.session.completed"
      payment = Payment.find_by(stripe_checkout_session_id: event.data.object.id)
      payment&.mark_paid!(payment_intent_id: event.data.object.payment_intent)
    when "checkout.session.expired"
      Payment.find_by(stripe_checkout_session_id: event.data.object.id)&.mark_failed!
    end

    head :ok
  rescue Stripe::SignatureVerificationError, JSON::ParserError
    head :bad_request
  end
end
