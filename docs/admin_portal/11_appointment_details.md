# 11 — Appointment Details

**Mockup:** `admin_portal.png`, row 3 col 3
**Phase:** 1 for the core view; the Payment Status badge is Phase 2/3
**Route:** `GET /staff/appointments/:id` (`staff_appointment_path`) — new `Staff::AppointmentsController#show`

## Purpose

Staff-side detail view of one appointment, with Reschedule/Cancel actions —
the staff equivalent of the patient's own reschedule flow
(`bookings/show.html.erb` when `@editing_appointment` is set), but staff can act
on *any* patient's appointment at their clinic, not just their own.

## UI elements

- Back + "Appointment Details" + "⋮" menu
- Patient summary card (avatar, name, age • sex, phone)
- Details list: Service, Doctor, Date, Time, Status (badge), Payment Status
  (badge), Notes
- "Reschedule" (outline button) and "Cancel Appointment" (red outline button)

## Data

**Existing — zero migration** for everything except Payment Status: Service,
Doctor, Date, Time, Status, Notes all come straight off `Appointment`. Reschedule
can reuse the exact same `AppointmentBooking#reschedule` + `Staff::AppointmentsController#update`
pattern the patient side already has (`AppointmentsController#update` in this
session's work) — just needs a staff-authorized variant that can target any
patient's appointment at the clinic, not `current_user.patient_appointments`.

**New:** "Payment Status" (Paid/Pending badge) has no backing field —
`Appointment` doesn't track payment at all. Either:
- cut this row until [15 Billing & Payments](15_billing_payments.md) exists, or
- add a minimal `payment_status` enum directly on `Appointment` now (paid /
  unpaid) as a placeholder ahead of full billing, if the client wants it sooner

`Appointment` already has a `notes` text column (`db/schema.rb`) for "Patient
complains of fever and body pain" — it's just not exposed in any current UI
(patient booking wizard doesn't collect it either). Zero migration for this field.

## Out of scope for v1

- Payment collection/recording UI (that's [15](15_billing_payments.md)) — this
  page only *displays* payment status, doesn't set it, until billing exists

## Acceptance checklist

- [ ] Staff can only view/act on appointments at their own clinic (reuse the
      `ClinicStaff` authorization check, not `current_user.patient_appointments`
      like the patient-facing controller uses)
- [ ] Reschedule reuses `AppointmentBooking`, doesn't duplicate its logic
- [ ] Cancel uses the same confirm-dialog pattern already built
      (`Turbo.config.forms.confirm` in `app/javascript/application.js`) for
      consistency
