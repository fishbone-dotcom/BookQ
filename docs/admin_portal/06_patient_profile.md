# 06 — Patient Profile

**Mockup:** `admin_portal.png`, row 2 col 2
**Phase:** 2 (small migration)
**Route:** `GET /staff/patients/:id` (`staff_patient_path`) — new `Staff::PatientsController#show`

## Purpose

Single patient's detail view: contact info + tabs into their history.

## UI elements

- Back + "Patient Profile" + edit icon
- Avatar, name, age • sex, phone
- Tabs: Overview | Records | Appointments | Files
- Overview tab — "Personal Information": email, address, blood type, allergies,
  emergency contact (name, relationship, phone)
- "＋ New Record" button → [Add Medical Record](08_add_medical_record.md)

## Data

**Existing:** email (`User#email`), Appointments tab
(`user.patient_appointments.where(clinic: clinic)`).

**New — migration needed:** address, blood type, allergies, emergency contact
name/phone on `User` (see [05](05_patients_list.md) — do this migration once for
both pages, also add birthdate/sex there). Consider whether these belong on
`User` directly or a separate `PatientProfile` model — since a patient's medical
demographics aren't really about their login account, and not every `User` is a
patient, a `has_one :patient_profile` is arguably cleaner than bloating `User`
with clinical fields. Decide before migrating; changing it later means a second
migration + data move.

**New — no model yet:** Records tab and Files tab depend on
[07 Patient Records](07_patient_records.md), which is Phase 3. Ship Overview and
Appointments tabs first; Records/Files tabs can show a "coming soon" state.

## Out of scope for v1

- Files tab (attachments) — needs Active Storage, same open question as
  [04 Add Doctor](04_add_doctor.md)'s photo upload; resolve once, reuse

## Acceptance checklist

- [ ] Editing personal info uses strong params, doesn't let staff set
      patient-account fields they shouldn't touch (e.g. `role`)
- [ ] Blank/optional fields (allergies "None," no emergency contact) render
      sensibly, not as raw `nil`/blank rows
- [ ] Appointments tab correctly scopes to this clinic only, in case the patient
      has booked at other clinics too
