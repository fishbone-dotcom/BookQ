# 01 — Dashboard

**Mockup:** `admin_portal.png`, row 1 col 1
**Phase:** 1
**Route:** `GET /staff/dashboard` (`staff_dashboard_path`) — new `Staff::DashboardsController#show`

## Purpose

Landing page for a clinic staff member after login: today's numbers, plus a quick
list of the next few appointments. Scoped to the clinic(s) the current user belongs
to via `ClinicStaff` — if they staff more than one clinic, needs a clinic switcher
(see [02](02_navigation.md)) rather than showing all clinics mixed together.

## UI elements

- Header: "Dashboard" + notification bell (bell can be a static icon for now —
  there's no notification model; wire it up once [16 Settings → Notifications]
  or a real notification feature is scoped)
- Greeting: "Good morning, {name}! 👋" + "Here's what's happening in your clinic
  today." (swap "Good morning" for a time-of-day-aware greeting, or keep it static
  — designer's call)
- 4 stat cards, each with a "View all" link:
  - Today's Appointments (count) → links to Appointments list filtered to today
  - Total Patients (count) → links to Patients list
  - Doctors (count) → links to Doctors list
  - New Patients (This Month) (count) → links to Patients list filtered by
    created-this-month
- "Recent Appointments" section with "View all" → Appointments list. Each row:
  time, patient name, service name, doctor name, status badge (pending/confirmed
  color-coded, matches the badge styles already used in `admin/dashboards/show.html.erb`)
- Bottom tab bar: Dashboard / Appointments / Patients / More (see [02](02_navigation.md)
  for what "More" opens)

## Data

**Existing — no migration needed:**
- Today's Appointments: `clinic.appointments.where(starts_at: Date.current.all_day)`
- Doctors count: `clinic.clinic_staffs.count` (or filter to a "doctor" concept —
  see note in [03](03_doctors_list.md) about there being no doctor/staff distinction
  yet, everyone in `ClinicStaff` is generically "staff" or "owner")
- Total Patients: distinct patients who have ever booked at this clinic —
  `User.joins(:patient_appointments).where(appointments: { clinic_id: clinic.id }).distinct.count`
- New Patients (This Month): same query, `.where(users: { created_at: Date.current.all_month })`
  — this is patients whose *account* was created this month, not their first booking
  at this clinic; note the ambiguity when you build it, pick whichever the client means
- Recent Appointments: `clinic.appointments.includes(:patient, :service, :staff).order(starts_at: :asc).where(starts_at: Time.current..)`

**New:** none.

## Authorization

Must check `current_user.clinic_staffs.exists?(clinic_id: @clinic.id)` before
rendering — same IDOR concern called out in `docs/CODING_STANDARDS.md`. A patient
or a staffer at a *different* clinic must not be able to load this page for a
clinic they don't belong to.

## Out of scope for v1

- Notification bell functionality (static icon only)
- Time-of-day-aware greeting (nice-to-have, skip unless asked)

## Acceptance checklist

- [ ] Stat counts match what's actually in the DB for the signed-in staffer's clinic
- [ ] A staffer at Clinic A cannot see Clinic B's numbers (test with two clinics)
- [ ] A `patient`-role user gets redirected/403'd, cannot reach this route
- [ ] Recent Appointments list is ordered soonest-first and excludes cancelled
- [ ] Status badge colors match the existing admin dashboard's badge convention
