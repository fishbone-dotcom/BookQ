class AppointmentCheckout
  Result = Struct.new(:checkout_url, :success?, :error, keyword_init: true)

  def self.create_for(appointment, success_url:, cancel_url:)
    new(appointment, success_url: success_url, cancel_url: cancel_url).create
  end

  def initialize(appointment, success_url:, cancel_url:)
    @appointment = appointment
    @success_url = success_url
    @cancel_url = cancel_url
  end

  def create
    session = Stripe::Checkout::Session.create(
      mode: "payment",
      line_items: [ {
        price_data: {
          currency: "php",
          unit_amount: (appointment.service.price * 100).to_i,
          product_data: { name: "#{appointment.service.name} at #{appointment.clinic.name}" }
        },
        quantity: 1
      } ],
      customer_email: appointment.contact_email,
      success_url: success_url,
      cancel_url: cancel_url,
      expires_at: 30.minutes.from_now.to_i,
      metadata: { appointment_id: appointment.id }
    )

    Payment.create!(appointment: appointment, clinic: appointment.clinic,
      amount: appointment.service.price, status: :pending, stripe_checkout_session_id: session.id)

    Result.new(checkout_url: session.url, success?: true)
  rescue Stripe::StripeError => e
    appointment.cancel!(by: nil, reason: "Could not start payment: #{e.message}")
    Result.new(success?: false, error: "We couldn't start payment. Please try booking again.")
  end

  private

  attr_reader :appointment, :success_url, :cancel_url
end
