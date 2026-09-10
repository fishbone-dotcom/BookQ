class Payment < ApplicationRecord
  belongs_to :appointment
  belongs_to :clinic

  enum :status, { pending: 0, paid: 1, failed: 2, refunded: 3 }

  validates :amount, numericality: { greater_than: 0 }
  validates :stripe_checkout_session_id, presence: true, uniqueness: true

  # Idempotent: Stripe retries webhook delivery, and the checkout-return
  # reconciliation in BookingsController can race the webhook to call this.
  def mark_paid!(payment_intent_id:)
    return if paid?

    update!(status: :paid, stripe_payment_intent_id: payment_intent_id)
    AppointmentMailer.confirmation(appointment).deliver_later if appointment.guest?
  end

  def mark_failed!
    return if paid? || failed?

    update!(status: :failed)
    appointment.cancel!(by: nil, reason: "Payment was not completed in time")
  end
end
