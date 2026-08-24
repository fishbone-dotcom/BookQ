# 07 — Patient Records

**Mockup:** `admin_portal.png`, row 2 col 3
**Phase:** 3 (new subsystem)
**Route:** `GET /staff/patients/:id/records` (`staff_patient_records_path`) — new controller

## Purpose

Timeline of a patient's clinical visit history (diagnosis, notes, related doctor),
independent of the appointment-booking `Appointment` record.

## UI elements

- Back + "Patient Records" + filter icon
- Patient header (reuse from [06](06_patient_profile.md))
- Vertical timeline: date, visit type, diagnosis, doctor, "View Details" link
- "＋ Add New Record" → [Add Medical Record](08_add_medical_record.md)

## Data

**New table required — no existing model covers this.** `Appointment` is a
*booking* (who/when/service), not a *clinical encounter* (what was actually
diagnosed/treated). They're related but distinct: a record might reference the
appointment it came from, or might be entered standalone (e.g. the "Laboratory
Test" entry in the mockup with no obvious linked appointment).

Proposed model:

```ruby
create_table :medical_records do |t|
  t.references :patient, null: false, foreign_key: { to_table: :users }
  t.references :clinic, null: false, foreign_key: true
  t.references :appointment, foreign_key: true # optional — nullable
  t.references :doctor, foreign_key: { to_table: :users } # optional, nullable
  t.date :visit_date, null: false
  t.string :visit_type, null: false # or an enum if the type list is fixed
  t.text :diagnosis
  t.text :treatment_notes
  t.timestamps
end
```

This is genuinely new scope — worth confirming with the client that an EMR-lite
feature (storing diagnoses/treatment notes) is actually wanted before building
it, given the privacy/compliance weight clinical data carries that appointment
scheduling data doesn't. `docs/CODING_STANDARDS.md`'s security rules (scoping,
strong params) apply doubly hard here.

## Out of scope for v1

- File attachments per record (Files tab) — bundle with whatever Active Storage
  decision gets made in [04](04_add_doctor.md)/[06](06_patient_profile.md)

## Acceptance checklist

- [ ] Only staff at the record's clinic (not any staff anywhere) can read it
- [ ] Records are scoped to one patient + this clinic; a patient's records at
      Clinic A never leak into Clinic B's staff view
- [ ] Timeline sorts newest-first, matches mockup
