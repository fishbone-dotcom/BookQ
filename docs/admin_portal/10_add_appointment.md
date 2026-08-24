# 10 — Add Appointment

**Mockup:** `admin_portal.png`, row 3 col 2
**Phase:** 1 (zero migration)
**Route:** `GET/POST /staff/appointments/new` — new `Staff::AppointmentsController#new`/`#create`

## Purpose

Staff books an appointment **on behalf of a patient** — e.g. a phone booking or
walk-in. This is the mirror image of the patient-facing `BookingsController`,
but the patient is selected rather than implied by `current_user`, and staff
should be able to bypass the "one active booking per patient" rule if needed
(a clinic may legitimately want to double-book a walk-in) — decide deliberately
rather than reusing the patient flow's validation untouched.

## UI elements

- Back + "Add Appointment"
- Patient (select — searchable), Doctor (select), Service/Type (select), Date
  (date picker), Time (select), Notes (optional textarea)
- "Save Appointment" button

## Data

**Existing — zero migration:** this is the same `Appointment` model, `Service`,
`ClinicStaff`/staff selection, and `SlotFinder` availability logic the patient
booking wizard already uses. Strongly prefer **reusing `AppointmentBooking`**
(`app/services/appointment_booking.rb`, added this session) rather than
duplicating booking logic a third time — it already handles service/staff/time
resolution and save-with-errors. The only real difference here is *which* user
becomes `patient:` (a selected patient, not `current_user`), and whether the
"already has an active booking" guard applies to staff-created bookings.

**New:** Patient select needs a search-as-you-type endpoint over
`User.where(role: :patient)` (or clinic's patient list per
[05](05_patients_list.md)) — a small JSON endpoint or a Turbo Frame, not a new
model.

## Out of scope for v1

- Overriding the one-active-booking rule per patient (make an explicit product
  decision, don't silently bypass a validation another part of the app depends on)

## Acceptance checklist

- [ ] Reuses `AppointmentBooking` rather than re-implementing slot/overlap logic
- [ ] Patient search only returns patients (not staff/admin accounts)
- [ ] Time select only offers real open slots (same `SlotFinder` the patient
      wizard uses) — don't let staff create an overlapping appointment by hand
- [ ] Strong params — service/staff/date/time only, never lets the form set
      `status` to something staff shouldn't be able to set directly (e.g.
      `completed` before the visit happens) unless that's an intentional feature
