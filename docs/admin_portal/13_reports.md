# 13 — Reports

**Mockup:** `admin_portal.png`, row 4 col 1
**Phase:** 3 (some reports possible sooner, others block on other Phase 3 pages)
**Route:** `GET /staff/reports` (`staff_reports_path`) — new `Staff::ReportsController#index` + one action per report

## Purpose

Landing grid of report types; each card opens its own report page (not detailed
individually here — six sub-pages, size each as its own doc once this one's
prioritized).

## UI elements

- Back + "Reports" + period dropdown ("This Month")
- Grid of report cards: Appointments Report, Patient Report, Doctors Performance,
  Revenue Report, Services Report, Inventory Report

## Data — per report, what it needs

| Report | Needs | Ready now? |
|---|---|---|
| Appointments Report | `Appointment` (counts/status breakdown over a period) | Yes — zero migration |
| Patient Report | `User` + `patient_appointments` (new/returning counts) | Yes — zero migration |
| Services Report | `Service` + `Appointment` (bookings per service) | Yes — zero migration |
| Doctors Performance | `ClinicStaff`/`staff_appointments` (appointments handled, maybe ratings — no rating model exists) | Mostly — counts yes, ratings no |
| Revenue Report | needs `Service#price` × completed appointments, or real payment records | Partial — `Service#price` exists, but without [15 Billing](15_billing_payments.md) this is an estimate, not actual collected revenue |
| Inventory Report | [14 Inventory](14_inventory.md) | No — blocked entirely |

Recommendation: build the landing grid + the three "Ready now" reports first;
stub the other three as "coming soon" cards until their dependencies exist.

## Acceptance checklist

- [ ] Landing grid only links to implemented reports; unimplemented ones are
      visibly disabled/labeled, not dead links
- [ ] Period dropdown ("This Month" etc.) actually changes the query range,
      isn't decorative
