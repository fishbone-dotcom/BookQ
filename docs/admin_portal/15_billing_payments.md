# 15 — Billing & Payments

**Mockup:** `admin_portal.png`, row 4 col 3
**Phase:** 3 (new subsystem)
**Route:** `GET /staff/billing` (`staff_billing_path`) — new controller + model

## Purpose

Revenue snapshot + recent payment transactions. Like
[14 Inventory](14_inventory.md), this is a genuinely new subsystem — actual
payment handling is a meaningfully different risk category from booking data
(money, potentially PCI-adjacent if real card processing gets involved later).
Scope this conversation explicitly before writing code: is this just
*recording* that a payment happened (staff manually marks paid/pending, cash-
register style), or does it need to actually process payments (a payment
gateway integration)? The mockup's badges ("Paid"/"Pending") read like the
former — manual record-keeping, not gateway integration. Confirm before
building either one.

## UI elements

- Header "Billing & Payments" + "＋ add"
- Stats: Today's Revenue, This Month (each with "View details")
- "Recent Transactions" list: patient, date, amount, status badge (Paid/Pending)

## Data

**New table required** (assuming the manual-recording interpretation above):

```ruby
create_table :payments do |t|
  t.references :appointment, null: false, foreign_key: true
  t.references :clinic, null: false, foreign_key: true
  t.decimal :amount, precision: 10, scale: 2, null: false # match Service#price's precision/scale convention
  t.integer :status, null: false, default: 0 # enum: pending, paid
  t.timestamps
end
```

One `payment` per `appointment` is the simplest model that satisfies the mockup;
revisit if partial payments/refunds turn out to be needed later — don't build
that speculatively now (per this codebase's "don't design for hypothetical
future requirements" convention).

This is also what would eventually back the "Payment Status" badge on
[11 Appointment Details](11_appointment_details.md) and the Revenue Report in
[13 Reports](13_reports.md).

## Out of scope for v1

- Actual payment gateway/card processing — explicitly confirm before ever
  starting this; it's a different project, not an incremental step past manual
  record-keeping
- Refunds/partial payments

## Acceptance checklist

- [ ] Confirm manual-recording vs. gateway-integration scope with the client
      before writing any code
- [ ] Money fields use `decimal` with explicit precision/scale, matching
      `Service#price`'s existing convention (never `float`)
- [ ] Revenue stats scoped to the current clinic only
