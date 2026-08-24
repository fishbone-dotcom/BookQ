# 08 — Add Medical Record

**Mockup:** `admin_portal.png`, row 2 col 4
**Phase:** 3 (new subsystem)
**Route:** `GET/POST /staff/patients/:id/records/new` — depends on [07](07_patient_records.md)'s model existing first

## Purpose

Form to log a new clinical encounter for a patient.

## UI elements

- Back + "Add Medical Record"
- Visit Date (date picker), Type (select), Diagnosis (textarea), Treatment/Notes
  (textarea), Doctor (select), Attachments ("＋ Upload File")
- "Save Record" button

## Data

Entirely dependent on the `medical_records` table proposed in
[07 Patient Records](07_patient_records.md) — don't start this doc's page until
that model is committed and migrated.

Doctor select reuses `clinic.staff_members` (same source as the booking wizard's
doctor step and [03 Doctors list](03_doctors_list.md)).

## Out of scope for v1

- Attachments (see [07](07_patient_records.md) — Active Storage decision)
- "Type" as a free-select vs. a fixed enum — mockup shows a dropdown, implying a
  fixed list (e.g. Consultation / Check-up / Lab Test / Procedure); confirm the
  actual list wanted rather than guessing categories

## Acceptance checklist

- [ ] Strong params, scoped to the current clinic's patient (can't file a record
      against a patient/clinic combo the staffer doesn't have access to)
- [ ] Diagnosis/notes are plain text rendered escaped (no `raw`/`html_safe`) —
      this is clinical free-text, exactly the kind of field that needs the
      default ERB escaping called out in `docs/CODING_STANDARDS.md`
