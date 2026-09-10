# 15 — Billing & Payments

**Mockup:** `admin_portal.png`, row 4 col 3
**Phase:** 3
**Route:** `GET /staff/billing` (`staff_billing_path`) — new controller, existing `Payment` model

## Purpose

Revenue snapshot + recent payment transactions.

**Update:** gateway integration is no longer out of scope — real Stripe
Checkout now runs at booking time (see `app/services/appointment_checkout.rb`,
`app/models/payment.rb`, `app/controllers/stripe_webhooks_controller.rb`).
Every paid appointment already has a real `Payment` record (`pending` while
Checkout is in progress, `paid` once Stripe confirms via webhook, `failed` if
the Checkout session expired unpaid). This page is now a **read/reporting**
surface over that existing data, not a decision about whether to build manual
record-keeping vs. a gateway — that decision is made.

## UI elements

- Header "Billing & Payments" + "＋ add"
- Stats: Today's Revenue, This Month (each with "View details") — sum
  `Payment.paid` amounts for the current clinic, scoped by date
- "Recent Transactions" list: patient, date, amount, status badge
  (Paid/Pending/Failed/Refunded) — reads `Payment#status` directly, no manual
  entry UI needed

## Data

Table already exists (`db/migrate/..._create_payments.rb`,
`app/models/payment.rb`):

```ruby
create_table :payments do |t|
  t.references :appointment, null: false, foreign_key: true
  t.references :clinic, null: false, foreign_key: true
  t.decimal :amount, precision: 10, scale: 2, null: false
  t.integer :status, null: false, default: 0 # pending, paid, failed, refunded
  t.string :stripe_checkout_session_id
  t.string :stripe_payment_intent_id
  t.timestamps
end
```

One `payment` per `appointment`. This also backs the "Payment Status" badge
on [11 Appointment Details](11_appointment_details.md) and the Revenue Report
in [13 Reports](13_reports.md) — join through `Appointment` rather than
re-deriving payment state elsewhere.

## Out of scope (still)

- **Stripe Connect / per-clinic payouts** — all charges currently settle into
  a single platform Stripe account; clinics are paid out manually outside the
  app. Routing charges directly to each clinic's own Stripe account is a
  distinct, larger project (OAuth onboarding, per-clinic account storage,
  Connect webhooks), not an incremental step past this.
- **Refunds/partial payments** — the `refunded` status exists on the enum for
  future use, but nothing sets it yet; cancelling an already-paid appointment
  today does not trigger a Stripe refund.
- A "＋ add" manual-payment flow — with gateway integration in place, this
  button's purpose (if kept at all) would be a manual override/adjustment,
  not primary data entry. Design that separately if it's still wanted.

## Acceptance checklist

- [ ] Revenue stats scoped to the current clinic only, and only count
      `Payment.paid` rows (not `pending`/`failed`)
- [ ] Status badge maps all four `Payment` statuses, not just Paid/Pending
- [ ] Confirm with the client whether a manual "＋ add" action still makes
      sense now that most payments flow through Stripe automatically
