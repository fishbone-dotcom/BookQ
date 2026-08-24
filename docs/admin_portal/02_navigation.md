# 02 — Navigation drawer ("Menu")

**Mockup:** `admin_portal.png`, row 1 col 2
**Phase:** 1
**Route:** not a page — a shared partial/layout piece used across every Staff:: page

## Purpose

The slide-out (or persistent, on wider screens) nav for the whole staff portal.
Distinct from the patient-facing app's nav (which we deliberately stripped down to
nothing in the home/booking pages per earlier work in this session) — staff users
doing real clinic-management work benefit from a persistent nav the way patients
booking one appointment don't.

## UI elements

- Close button (this is a drawer/overlay on mobile, not a permanent sidebar)
- Nav items, each with an icon: Dashboard, Appointments, Doctors, Patients,
  Patient Records, Billing & Payments, Inventory, Reports, Notifications, Settings
- Footer: clinic switcher row ("CarePoint Clinic — Main Branch" with a chevron —
  only relevant if `current_user.clinics.count > 1`; hide or collapse to plain
  text if the staffer only belongs to one clinic) and an account row (avatar,
  name, role label e.g. "Super Administrator" — map to `current_user.display_name`
  and a humanized `ClinicStaff#role`/`User#role`)

## Data

**Existing:** `current_user.clinics` (via `ClinicStaff`) for the switcher;
`current_user.display_name`, `current_user.role` for the footer.

**New:** none for the nav shell itself. Individual nav destinations may be
Phase 2/3 pages (Patient Records, Billing & Payments, Inventory) — link to them
but they 404/"coming soon" until their own doc is implemented. Don't block
shipping the nav on every destination existing.

## Out of scope for v1

- Multi-branch clinic switching logic beyond a simple dropdown (no cross-branch
  data aggregation)
- "Notifications" as a real inbox — link can be a placeholder until a
  notifications feature is scoped

## Acceptance checklist

- [ ] Every implemented Phase 1 page (Dashboard, Doctors, Patients, Appointments,
      Calendar) is reachable from this nav
- [ ] Unimplemented destinations either don't render as links yet, or show a
      clearly-labeled "coming soon" state — no dead 404s presented as if they work
- [ ] Clinic switcher only appears when the staffer actually belongs to >1 clinic
- [ ] Nav closes/collapses correctly on mobile after selecting an item
