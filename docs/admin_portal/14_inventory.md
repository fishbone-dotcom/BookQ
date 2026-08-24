# 14 — Inventory

**Mockup:** `admin_portal.png`, row 4 col 2
**Phase:** 3 (new subsystem)
**Route:** `GET /staff/inventory` (`staff_inventory_items_path`) — new controller + model

## Purpose

Track clinic supplies/medicine stock. Entirely unrelated to appointment booking
— this is the biggest scope addition in the whole mockup relative to what BookQ
is today (per `CLAUDE.md`: "a clinic booking SaaS"). Worth explicitly confirming
this is wanted before building, since it's a full mini inventory-management
feature, not a small add-on.

## UI elements

- Header "Inventory" + "＋ add"
- Search "Search items..." + filter
- Rows: icon, item name, category (Tablet/Capsule/Medical Supply/Bottle/Box),
  stock count

## Data

**New table required:**

```ruby
create_table :inventory_items do |t|
  t.references :clinic, null: false, foreign_key: true
  t.string :name, null: false
  t.string :category, null: false # or an enum if the category list is fixed
  t.integer :stock, null: false, default: 0
  t.timestamps
end
```

Low-stock alerting, stock-in/stock-out history, and linking consumed items to
appointments (e.g. "this visit used 2 syringes") are all visible next-steps once
this exists, but none of that is in the mockup's Inventory screen itself — don't
build ahead of what's actually shown.

## Out of scope for v1

- Stock movement history/audit log
- Auto-decrementing stock from appointments/records (would need a real
  usage-tracking design, not implied by this screen)

## Acceptance checklist

- [ ] Confirm with the client this feature is actually wanted before starting —
      it's the single largest net-new subsystem in the whole mockup
- [ ] Scoped per clinic, same authorization pattern as every other Staff:: page
- [ ] Search filters by name/category
