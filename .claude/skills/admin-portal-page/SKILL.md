---
name: admin-portal-page
description: Implement one page from docs/admin_portal/ (the staff/clinic-owner console) end to end — controller, view, tests, e2e check, commit, push. Use whenever the user asks to build, continue, or work on a numbered admin-portal page (e.g. "03 Doctors list", "gawin na natin yung Patients page", "next page sa roadmap").
---

# Admin Portal Page Implementation

Builds one page from `docs/admin_portal/` (the staff-facing clinic console —
distinct from `Admin::DashboardsController`, which is the system-wide admin
dashboard) following the exact workflow this codebase has used for every page
so far (Dashboard, Navigation, Appointments list, Add Appointment, Calendar
View — all in `docs/admin_portal/README.md`, all built this way).

## Steps

1. **Read the page's own doc** (`docs/admin_portal/0N_page_name.md`) in full —
   Purpose, UI elements, Data (existing vs. new — migrations needed), Out of
   scope for v1, Acceptance checklist. Read `docs/admin_portal/README.md` too
   for the phase this page belongs to and any cross-page notes.
2. **Check for a migration first** if the Data section says one is needed.
   Don't start the controller/view until the schema is in place.
3. **Route**: add under the `namespace :staff do ... end` block in
   `config/routes.rb`.
4. **Controller**: `Staff::<Name>Controller < Staff::BaseController` (gives
   `authenticate_user!`, clinic scoping via `@clinic`/`@clinic_staff`, and the
   `layout "staff"` — never render outside this base controller or you lose
   the shared nav/layout). Reuse existing services rather than reimplementing
   logic a page already has elsewhere:
   - `AppointmentBooking` for anything that creates/reschedules an appointment
   - `SlotFinder` for anything that needs available time slots
   - `CalendarLayout` for anything positioning appointments on a time grid
5. **View**: lives in the shared `layouts/staff.html.erb` (hamburger + title +
   bell header, bottom tab bar) — set the header title with
   `<% content_for(:page_title, "...") %>` at the top of the page template,
   don't rebuild the header. Match established UI conventions, don't
   introduce new ones:
   - **No native `<select>` dropdowns.** Every choice (service, doctor,
     patient, status filter) is a styled radio-card: `sr-only` radio input
     inside a `<label>` with `has-checked:border-emerald-600
     has-checked:bg-emerald-50`, a leading icon/avatar circle, and a trailing
     checkmark circle. Copy the exact markup from
     `app/views/bookings/show.html.erb` or a page already built.
   - **Day-strip navigation** (week view + month label): render the shared
     `staff/_day_strip` partial, don't rebuild it.
   - **List/Calendar view toggle**: render the shared `staff/_view_toggle`
     partial when a page has both views.
   - **Auto-submitting a GET form on a field change** (e.g. picking a service
     reloads to refresh available time slots): `data: { controller:
     "auto-submit" }` on the form, `data-action="change->auto-submit#submit"`
     on the field. Only fields that actually change server-computed state
     (slots, filtered lists) need this — a field that's just carried through
     for later submission (e.g. `staff_id` when only `service_id`/`date`
     affect slots) can be a plain hidden field.
   - **Live client-side search filter** over a list already on the page
     (patient search, clinic search): a small per-page Stimulus controller
     with `input`/`item`/`empty` targets — copy
     `app/javascript/controllers/staff_patient_search_controller.js` or
     `clinic_search_controller.js`.
   - Placeholder nav destinations not built yet render as inert (no `href`)
     rows with a small gray "Soon" badge — never a link to a 404. Once a page
     ships, promote its drawer entry (`staff/_navigation.html.erb`) and bottom
     tab bar entry (`layouts/staff.html.erb`, if applicable) from placeholder
     to a real `link_to`.
6. **Strong params discipline**: never let a form set `status` or any other
   column the doc doesn't list as a field. `AppointmentBooking` already
   enforces this for appointment status — don't bypass it by hand-building an
   `Appointment.new`/`.update` call.
7. **Rebuild Tailwind before checking your work**:
   `bin/rails tailwindcss:build`. The watch process does not survive in this
   sandbox (dies almost immediately, no error — looks like restricted
   inotify), so any new utility class you just used will silently be missing
   from the compiled CSS and the page will render broken/unstyled until you
   rebuild by hand. Do this after every round of view edits, not just once.
8. **Write RSpec request specs** covering the doc's acceptance checklist
   directly — one `it` block per checklist item is a reasonable default.
   Always include: requires authentication, redirects a non-staff user,
   scoped to the current clinic only (create a second clinic in the spec and
   assert its data doesn't leak).
9. **Run the full check**: `bundle exec rspec`, `bin/rubocop`, `bin/brakeman
   -q` — all clean, not just the new spec file.
10. **Write and run an e2e Playwright check** — see the `e2e-check` skill for
    how; every shipped page has a matching `e2e/staff_<page>.js`.
11. **Commit** (this page only — see the git history for message style: what
    changed and why, not just what) and **push**.
12. **Check off the page** in `docs/admin_portal/README.md`
    (`- [x] ... — controller/key file, commit-sha`) before starting the next
    one.

## Things that have already bitten this codebase — don't repeat them

- Forgetting to rebuild Tailwind after a view change (see step 7) — the most
  common false "bug" this session, always rule this out first before
  debugging application logic.
- `.includes(:association)` in a controller query that the view stops using
  after an edit — Bullet flags this as a visible warning banner in the
  browser in development. If you remove a field from a card/view, check
  whether the controller's `includes` needs to drop it too.
- The **first** request to a route/controller that was just added can be
  noticeably slower (Rails dev-mode autoloading it for the first time) and
  can cause a single e2e check to fail on timeout. Re-run once before
  concluding there's a real bug.
- A Turbo-intercepted `button_to` (the default) against a Devise action like
  sign-out can silently fail to update the page even though the server-side
  action succeeded, because Devise doesn't respond to the `turbo_stream`
  format Turbo requests. Use `data: { turbo: false }` on session-ending
  buttons.
