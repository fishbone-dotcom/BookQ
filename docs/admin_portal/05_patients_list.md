# 05 — Patients list

**Mockup:** `admin_portal.png`, row 2 col 1
**Phase:** 2 (small migration)
**Route:** `GET /staff/patients` (`staff_patients_path`) — new `Staff::PatientsController#index`

## Purpose

List everyone who has booked at this clinic, so staff can look someone up.

## UI elements

- Header "Patients" + "＋" add button (manually adding a patient record —
  useful for walk-ins who book by phone rather than through the app)
- Search "Search patients..." + filter
- Rows: avatar, name, age • sex, phone number

## Data

**Existing:** "who is a patient of this clinic" = distinct `User`s with a
`patient_appointments` row where `clinic_id` matches —
`User.joins(:patient_appointments).where(appointments: { clinic_id: clinic.id }).distinct`.

**New — migration needed:** `User` has no birthdate (mockup shows age, so store
birthdate and compute age, not a raw age integer that goes stale) and no sex/phone
field. These are the same new `User` columns [06 Patient Profile](06_patient_profile.md)
needs — do this migration once, covering both pages.

## Open question this page forces

**Can staff add a patient who has no BookQ account at all** (the "＋" button —
e.g. an elderly walk-in patient who will never use the app themselves)? If yes,
`Appointment#patient` needs to tolerate a patient record that isn't a full login-
capable `User`, which is a bigger data-model decision (a lightweight `Patient`
concept separate from login `User`, vs. creating a passwordless `User` row for
every walk-in). Don't build the "＋" flow until this is decided — the list/search
part of this page doesn't depend on it and can ship first.

## Out of scope for v1

- The "＋ add patient" button (see open question above — split into its own doc
  once the account-vs-record question is answered)
- Advanced filters beyond name/phone search

## Acceptance checklist

- [ ] List only includes patients who've booked at *this* clinic, not every
      patient in the system
- [ ] Search matches name and phone
- [ ] No account lockout/security issue from exposing patient phone numbers to
      any authenticated staff member — confirm this clinic's staff, not just
      any signed-in user, per the IDOR rule in `docs/CODING_STANDARDS.md`
