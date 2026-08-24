# 04 — Add Doctor

**Mockup:** `admin_portal.png`, row 1 col 4
**Phase:** 2 (small migration)
**Route:** `GET/POST /staff/doctors/new` (`new_staff_doctor_path`) — `Staff::DoctorsController#new`/`#create`

## Purpose

Invite/add a doctor to the clinic and set their profile details.

## UI elements

- Back arrow + "Add Doctor" title
- Photo upload (circular, camera icon placeholder)
- Full Name, Specialization (select), Email, Phone Number, Status (select)
- "Save Doctor" button

## Data

**Existing:** `Clinic#staff_members` / `ClinicStaff` join already models "this
user works at this clinic." Adding a doctor is really: find-or-invite a `User`,
then create a `ClinicStaff` row for this clinic.

**New — migration needed (see [03](03_doctors_list.md)):** specialization,
status, phone on `ClinicStaff`. Photo needs Active Storage (`has_one_attached`)
— this app has zero Active Storage usage today, so adding it here is the first
place that decision gets made; if photo upload is deferred, fall back to the
initials-avatar pattern already in `ApplicationHelper#initials_for`.

## Open question this page forces

**Does "Add Doctor" create a brand-new `User` account, or invite an existing
one?** The mockup's plain "Email" field doesn't make this clear. Two real options:

1. Create a new `User` with `role: :staff` and no password (send a Devise
   invitation/reset-password-style email) — matches "this doctor doesn't have
   an account yet."
2. Look up an existing `User` by email and just attach a `ClinicStaff` — matches
   "this doctor already has a BookQ account, maybe from another clinic."

Pick one (or support both — find-or-create by email) before implementing; this
isn't a detail to guess silently since it changes the security model (does an
owner get to set an arbitrary password for someone else, or does the invitee
set their own?).

## Out of scope for v1

- Doctor login/invitation email flow — if going with option 1 above, sending an
  actual invite email can be stubbed (create the account, note the temp state)
  until the app has a real transactional email setup

## Acceptance checklist

- [ ] Strong params — only permit the fields this form actually shows, never
      `role` or clinic ownership from raw params (per `docs/CODING_STANDARDS.md`)
- [ ] Only a staffer with `owner` role (or however this app decides "can manage
      staff") can reach this page — plain `staff` role probably shouldn't add
      other doctors; decide and enforce
- [ ] Duplicate-email case (adding someone already staffing this clinic) shows a
      clear validation error, doesn't create a duplicate `ClinicStaff` row
      (there's already a `uniqueness: { scope: :clinic_id }` validation on
      `ClinicStaff#user_id` — confirm the form surfaces that error legibly)
