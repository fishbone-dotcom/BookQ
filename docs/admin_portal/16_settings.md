# 16 — Settings

**Mockup:** `admin_portal.png`, row 4 col 4
**Phase:** mixed — see per-row breakdown below
**Route:** `GET /staff/settings` (`staff_settings_path`) — new controller, likely
one action per settings sub-page rather than one giant form

## Purpose

Clinic + account configuration, grouped into three sections.

## UI elements & data, row by row

**Clinic Settings**
- Clinic Information → `Clinic#name`, address — **exists, zero migration**
  (check `db/schema.rb` for what columns `Clinic` actually has beyond `name`;
  the booking page already renders `@clinic.address`, so at least that much is there)
- Branches → clinic model has no parent/branch relationship today; "CarePoint
  Clinic — Main Branch" in the nav mockup implies multi-branch clinics are a
  real concept for this client. That's a data-model decision (self-referential
  `Clinic belongs_to :parent_clinic` vs. a separate `Branch` model) — **Phase 3,
  new subsystem**, don't casually bolt it on
- Working Hours → this is exactly the existing `Availability` model
  (day_of_week + start/end time) — **exists, zero migration**, just needs a
  settings-page CRUD UI instead of the current no-UI-at-all state (Availability
  rows currently only get created via `db/seeds.rb`)

**System Settings**
- Users & Roles → this is `ClinicStaff` (role: staff/owner) — **exists, zero
  migration**, needs a management UI (who's staff, who's owner, invite/remove)
- Preferences → nothing in the mockup specifies what these are; **don't build
  a placeholder settings page for undefined preferences** — cut until there's
  an actual list of what belongs here
- Backup & Restore → no concept of this anywhere in a standard Rails app scoped
  to one clinic's data (this usually means "export my data" or is literally a
  database-admin operation that shouldn't be exposed to clinic staff at all) —
  **Phase 3 at best, needs product clarification on what it's even supposed to do**

**Account**
- Profile → `current_user` edit (Devise registration edit already exists at
  `/users/edit`, per `app/views/devise/registrations/edit.html.erb`) — **exists**,
  this row can just link there
- Change Password → same — Devise already provides this via the profile edit
  page's password fields
- Logout → `destroy_user_session_path`, already used elsewhere in the app —
  **exists, zero migration**

## Recommendation

Ship in this order: Working Hours UI → Users & Roles UI → Clinic Information
edit → Profile/Change Password/Logout (just links to existing Devise pages).
Cut Branches, Preferences, and Backup & Restore from v1 entirely until each has
an actual spec — right now they're mockup rows with no defined behavior behind them.

## Acceptance checklist

- [ ] Working Hours edits validate the same way `Availability` already does
      (`end_time_after_start_time`)
- [ ] Users & Roles changes can't let a plain `staff` promote themselves to
      `owner` (authorization, not just UI hiding the button)
- [ ] Every settings row either links to something real or doesn't appear —
      no rows that look actionable but do nothing
