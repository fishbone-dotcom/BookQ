# 03 — Doctors list

**Mockup:** `admin_portal.png`, row 1 col 3
**Phase:** 2 (small migration)
**Route:** `GET /staff/doctors` (`staff_doctors_path`) — new `Staff::DoctorsController#index`

## Purpose

List everyone who provides services at the clinic, so staff can see who's
available and jump to editing/adding a doctor.

## UI elements

- Header "Doctors" + "＋" add button → [Add Doctor](04_add_doctor.md)
- Search bar "Search doctors..." + filter icon
- Rows: avatar, name, specialization, availability status badge
  (Available/On Leave), "⋮" overflow menu (edit/remove)

## Data

**Existing:** `clinic.clinic_staffs.includes(:user)` — this is exactly the list
already used in the patient-facing booking wizard's "Doctor" step
(`bookings_controller.rb#load_booking_context` → `@clinic_staffs`).

**New — migration needed.** Nothing on `ClinicStaff` or `User` currently holds:
- specialization (string)
- availability status (available / on_leave — an enum; note this is a *manual*
  status flag, unrelated to the `Availability` model which is about weekly open
  hours, not a person being present)
- phone number
- photo (would need Active Storage, which isn't set up anywhere in this app yet —
  see [04](04_add_doctor.md) for the call on whether to add it now or stub with
  initials like the patient portal's avatar circles already do)

Recommendation: put specialization/status/phone on `ClinicStaff` rather than
`User`, since a person could plausibly staff two clinics with different
specializations or status at each — matches the "scoped per-clinic" pattern
`ClinicStaff` already exists for.

## Out of scope for v1

- Real-time availability status (this is a manually-set flag, not computed from
  today's Availability/appointments — don't try to derive it)
- Doctor removal flow with in-flight-appointment handling — for v1, block removal
  if the doctor has any active appointments assigned (`staff_appointments.active`)
  rather than building reassignment UI

## Acceptance checklist

- [ ] List only shows staff for the current clinic (not other clinics the
      logged-in user might also belong to)
- [ ] Search filters by name (server-side or same live-filter JS pattern as the
      patient homepage's clinic search)
- [ ] Status badge color matches Available=green / On Leave=amber convention
