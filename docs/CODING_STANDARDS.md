# Coding Standards

Internal reference for BookQ: what "good" looks like in this codebase, common mistakes to avoid, and the security rules we don't compromise on. Examples below use real BookQ models where possible.

## 1. Good code vs. bad code

### Fat controllers vs. thin controllers

Business logic belongs in the model or a service object, not the controller. The controller's job is: receive params, call one thing, respond.

```ruby
# Bad — booking logic buried in the controller
class AppointmentsController < ApplicationController
  def create
    if Appointment.where(clinic_id: params[:clinic_id])
                  .where.not(status: :cancelled)
                  .where("starts_at < ? AND ends_at > ?", params[:ends_at], params[:starts_at])
                  .exists?
      redirect_to new_appointment_path, alert: "Slot taken"
      return
    end
    @appointment = Appointment.create(...)
  end
end
```

```ruby
# Good — the model already owns this rule (see Appointment#no_overlapping_appointments)
class AppointmentsController < ApplicationController
  def create
    @appointment = current_user.patient_appointments.build(appointment_params)
    if @appointment.save
      redirect_to @appointment, notice: "Booked"
    else
      render :new, status: :unprocessable_entity
    end
  end
end
```

If a create/update action needs more than a handful of lines to decide what happens, that's a sign it belongs in a service object (e.g. `app/services/appointment_booking.rb`), not inline in the controller.

### N+1 queries

Rails' association design makes N+1s the default failure mode, not an edge case.

```ruby
# Bad — one query per clinic to find its owner
@clinics.each { |c| puts c.owner.email }

# Good
@clinics = Clinic.includes(:owner)
```

Any index/list view that loops over a collection and touches an association must use `includes`/`preload`. Check with `bin/rails server` + watch the log for repeated `SELECT ... WHERE id = ?` — that's the tell.

### Querying vs. Ruby-side filtering

```ruby
# Bad — pulls every row into memory to filter in Ruby
Appointment.all.select { |a| a.status == "pending" }

# Good — let the database do it
Appointment.where(status: :pending)
```

### Validation placement

Business rules that determine whether data is *valid* go on the model (like `Appointment#no_overlapping_appointments`), not scattered as ad-hoc `if` checks in controllers or views. If the same rule needs enforcing from two call sites (web form + future API), a controller-only check will eventually drift out of sync; a model validation can't be bypassed.

### Naming

Follow Rails convention over inventing new patterns:
- Models: singular, `CamelCase` (`Appointment`, not `Appointments` or `AppointmentModel`)
- Tables/columns: `snake_case`, plural table names (`appointments`)
- Booleans: predicate methods read as questions (`confirmed?`, not `is_confirmed`)
- Enums: define with explicit integer mapping (as done in `Appointment#status`) so column values are stable even if the list is reordered in code later

## 2. Conventions

- **Fat model, skinny controller** — but a model that's outgrowing itself (multiple unrelated concerns) should split into a `Concern` or a plain Ruby service object under `app/services/`, not keep growing.
- **Foreign keys always explicit** when the association name doesn't match the table (`belongs_to :owner, class_name: "User"`, `belongs_to :staff, class_name: "User", optional: true`) — see `Clinic` and `Appointment`.
- **Enums over free-text status/role columns.** Already the pattern for `User#role`, `Appointment#status`, `ClinicStaff#role`, `Availability#day_of_week`. Keep using this rather than string columns compared with `==`.
- **Strong params** in every controller — never `params.permit!` or mass-assign raw `params[:user]`.
- **Tests live in `spec/`, not `test/`.** This project uses RSpec + FactoryBot (see `CLAUDE.md`); the `test/` directory is leftover `rails new` scaffolding and should not receive new files.
- **Migrations are additive and reversible.** Don't hand-edit a migration that has already been run and committed — write a new migration instead.
- **Money and durations are typed correctly**: `price` is `decimal` with explicit `precision/scale` (never `float`, which loses cents), `duration_minutes` is an integer, not a string to be parsed later.

## 3. Security

- **Strong parameters, always.** Every create/update action must whitelist permitted attributes explicitly. Never permit `role` or any other authorization-relevant column from user-submitted params — a patient signing up must not be able to set `role: "admin"` via a crafted form post.
- **Authorization is separate from authentication.** Devise confirms *who* the user is; it says nothing about what they're allowed to do. Every controller action touching clinic data must check that the current user actually owns/staffs that clinic (via `ClinicStaff`) before reading or mutating it — don't rely on the UI simply not showing the link.
- **Scope every query to the current user/clinic.** Never write `Appointment.find(params[:id])` in a controller that's reachable by more than one role — that lets user A load user B's data by guessing an ID (insecure direct object reference). Prefer `current_user.patient_appointments.find(params[:id])` or an explicit clinic-scoped lookup.
- **No raw SQL string interpolation.** `Appointment#no_overlapping_appointments` uses `where("starts_at < ? AND ends_at > ?", ends_at, starts_at)` — parameterized placeholders, not string interpolation of user input. Never write `where("email = '#{params[:email]}'")`.
- **Escaping is on by default in ERB (`<%= %>`)** — never reach for `raw()`, `html_safe`, or `<%== %>` on anything derived from user input (appointment notes, clinic name, etc.).
- **Secrets never get committed.** `config/master.key` is gitignored; `config/credentials.yml.enc` is safe to commit because it's encrypted by that key. `.kamal/secrets` only references environment/credentials lookups, never raw values — keep it that way.
- **CSRF protection stays on** (`protect_from_forgery`, default in `ApplicationController`) — don't disable it to make a form "easier" to submit.
- **Rate-limit or otherwise guard auth endpoints** before this app has real users — Devise's `:lockable` module (not currently enabled) is the standard way to slow down credential-stuffing against `/users/sign_in`.
