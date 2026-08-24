# 09 — Appointments list

**Mockup:** `admin_portal.png`, row 3 col 1
**Phase:** 1 (zero migration)
**Route:** `GET /staff/appointments` (`staff_appointments_path`) — new `Staff::AppointmentsController#index`

## Purpose

Staff-side view of the clinic's appointments for a given day, with status
filters — the clinic-staff counterpart to the patient's single-appointment home
card, and to the system-wide `Admin::DashboardsController` table (but scoped to
one clinic, day-based instead of a flat paginated table, and with a day-strip
picker instead of pagination).

## UI elements

- Header "Appointments" + "＋ add" → [Add Appointment](10_add_appointment.md)
- Month label + horizontal day strip (tap a day to filter)
- Filter chips: All / Confirmed / Pending / Cancelled
- Rows: time, patient name, service, doctor, status badge → tapping a row opens
  [Appointment Details](11_appointment_details.md)
- Bottom tab bar (same as [01 Dashboard](01_dashboard.md))

## Data

**Existing — zero migration:** `clinic.appointments.includes(:patient, :service, :staff)`,
filtered by `starts_at.to_date == selected_date` and optionally `status:`. This
is the same `Appointment` model and `status` enum already driving the patient
booking flow and the system-wide admin dashboard — no new columns needed.

## Out of scope for v1

- Multi-day range selection (mockup is single-day-at-a-time)

## Acceptance checklist

- [ ] Filter chips map 1:1 to `Appointment#status` enum values and actually
      filter the list (not just visually toggle)
- [ ] Day strip navigation preserves the active status filter across day changes
- [ ] List scoped to current clinic only — reuse the same authorization check as
      [01 Dashboard](01_dashboard.md)
- [ ] Cancelled appointments only appear under the "Cancelled" filter, not "All"
      by default, matching how the patient side treats them (or decide
      deliberately if "All" should mean literally all — note the choice)
