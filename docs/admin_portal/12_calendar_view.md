# 12 — Calendar View

**Mockup:** `admin_portal.png`, row 3 col 4
**Phase:** 1 (zero migration)
**Route:** `GET /staff/calendar` (`staff_calendar_path`) — new `Staff::CalendarController#show`

## Purpose

Same underlying data as [09 Appointments list](09_appointments_list.md), shown
as an hour-by-hour day grid instead of a flat list — useful for spotting gaps
and overlaps visually. Color-code by status (mockup shows pending in a distinct
yellow block vs. confirmed).

## UI elements

- Header "Calendar View" + filter icon
- Month label + day strip (same component as [09](09_appointments_list.md) —
  share a partial rather than building two day-strip pickers)
- Hourly rows (8 AM–2 PM shown, but the clinic's actual `Availability` hours
  should drive the range, not a hardcoded 8–2)
- Appointment blocks positioned/sized by `starts_at`/`ends_at`, colored by status
- Floating "＋" button → [Add Appointment](10_add_appointment.md)

## Data

**Existing — zero migration:** `clinic.appointments` for the selected day, plus
`clinic.availabilities` to compute the displayed hour range (reuse the same
open-hours data `SlotFinder` already reads).

## Out of scope for v1

- Drag-to-reschedule directly on the grid (mockup doesn't show this either —
  tapping a block should just open [Appointment Details](11_appointment_details.md))
- Multi-doctor side-by-side columns (mockup is a single merged timeline; per-doctor
  columns would be a natural v2 if the clinic has several doctors double-booked
  at the same hour)

## Acceptance checklist

- [ ] Block vertical position/height accurately reflects `starts_at`/duration
      (test with services of different `duration_minutes`, not just 30-min ones)
- [ ] Overlapping appointments (shouldn't normally happen given
      `Appointment#no_overlapping_appointments`, but different staff at the same
      time is valid) render side-by-side, not stacked illegibly
- [ ] Hour range adapts to the clinic's actual `Availability` for that day of week
