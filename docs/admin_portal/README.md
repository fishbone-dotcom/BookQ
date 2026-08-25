# Admin Portal — Implementation Plan

Source design: `tmp/screenshot/admin_portal.png` (16 mobile screens, 4x4 grid).

This is a **clinic staff console** — day-to-day tools for the people running a clinic
(the `staff`/`owner` side of `ClinicStaff`), scoped to one clinic at a time. It is
**not** the same thing as the existing `Admin::DashboardsController`, which is a
system-wide, admin-role-only view across all clinics. To avoid confusion with that
existing "Admin Dashboard," the routes/controllers for this new portal should live
under a `Staff::` namespace (e.g. `staff_dashboard_path`, `Staff::DoctorsController`),
not `Admin::`.

Each page below has its own doc (`0N_page_name.md`) so we can build, commit, push,
and test **one page at a time** instead of one giant PR. Work through them in the
phase order below — later phases depend on data models earlier phases don't need.

## Phase 1 — zero migrations, just new controllers/views

Every field these pages need already exists on `Clinic`, `ClinicStaff`, `User`,
`Service`, or `Appointment`:

- [x] [01 — Dashboard](01_dashboard.md) — `Staff::DashboardsController`, `7e49526`
- [x] [02 — Navigation drawer](02_navigation.md) — `layouts/staff.html.erb` + `staff/_navigation`
- [x] [09 — Appointments list](09_appointments_list.md) — `Staff::AppointmentsController#index`
- [x] [10 — Add Appointment](10_add_appointment.md) — `Staff::AppointmentsController#new/#create`, reuses `AppointmentBooking`
- [x] [12 — Calendar View](12_calendar_view.md) — `Staff::CalendarsController#show`, `CalendarLayout`

## Phase 2 — small migrations (new columns on existing models, no new tables)

- [x] [03 — Doctors list](03_doctors_list.md) — `Staff::DoctorsController#index`,
  specialization/status/phone added to `ClinicStaff`
- [x] [04 — Add Doctor](04_add_doctor.md) — `Staff::DoctorsController#new/#create`,
  find-or-create by email, owner-only, photo deferred (initials avatar)
- [ ] [05 — Patients list](05_patients_list.md) — needs birthdate/phone on `User`
- [ ] [06 — Patient Profile](06_patient_profile.md) — needs address, blood type,
  allergies, emergency contact on `User`
- [ ] [11 — Appointment Details](11_appointment_details.md) — mostly Phase 1, but the
  "Payment Status" badge needs either a stub column or should be cut until
  [15 Billing & Payments](15_billing_payments.md) exists

## Phase 3 — needs brand-new subsystems

Each of these needs at least one new model/table and isn't part of BookQ's current
scope (per `CLAUDE.md`: a booking app, not an EMR/inventory/billing system). Treat
these as separate feature proposals to size individually before starting:

- [ ] [07 — Patient Records](07_patient_records.md) (medical records subsystem)
- [ ] [08 — Add Medical Record](08_add_medical_record.md)
- [ ] [13 — Reports](13_reports.md) (depends on whichever of the above exist)
- [ ] [14 — Inventory](14_inventory.md) (new subsystem, unrelated to appointments)
- [ ] [15 — Billing & Payments](15_billing_payments.md) (new subsystem)
- [ ] [16 — Settings](16_settings.md) (mixed — some rows map to real features like
  Working Hours/`Availability`, others like Backup & Restore don't exist anywhere
  in the app yet)

## Workflow for each page

1. Read the page's doc — Data section tells you what migration (if any) comes first.
2. Implement controller + view + tests.
3. Run `bundle exec rspec`, `bin/rubocop`, `bin/brakeman` — all clean.
4. Walk through the page with Playwright (screenshot or short video) to compare
   against the mockup region cited in the doc.
5. Commit with a message naming just that page, push.
6. Check off the page in this README before moving to the next one.
