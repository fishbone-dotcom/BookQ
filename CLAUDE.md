# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
bin/rails server -b 0.0.0.0 -p 3000   # run dev server
bin/dev                                # run server + Tailwind watcher together

bundle exec rspec                      # run full test suite
bundle exec rspec spec/models/appointment_spec.rb        # run one file
bundle exec rspec spec/models/appointment_spec.rb:12      # run one example by line

bin/rails db:migrate                   # apply pending migrations
bin/rails db:test:prepare              # sync test DB schema (run after migrating, before rspec)

bin/rails tailwindcss:build            # rebuild Tailwind CSS manually (needed if not using bin/dev)

bin/rubocop                            # lint (rubocop-rails-omakase config)
bin/brakeman                           # security static analysis
```

## Architecture

BookQ is a clinic booking SaaS: a Rails 8.1 app (SQLite, Propshaft, Hotwire/Turbo, Tailwind) intended to replace manual Messenger-based clinic booking.

**Auth**: Devise on `User`, with a `role` enum (`patient`, `staff`, `admin`) driving which views/dashboards a user sees. There is no separate `Staff` model — clinic staff are `User` records linked via `ClinicStaff`.

**Multi-clinic data model** — one clinic can have many staff and many services; a patient books an appointment at a clinic for a specific service, optionally with a specific staff member:

- `Clinic belongs_to :owner` (a `User`)
- `ClinicStaff` joins `Clinic` <-> `User`, with its own `role` enum (`staff`, `owner`) scoped per-clinic, unique on `[clinic_id, user_id]`
- `Service belongs_to :clinic` — defines `duration_minutes` and `price` for a bookable offering
- `Availability belongs_to :clinic` — recurring weekly open hours (`day_of_week` enum + `start_time`/`end_time`), not yet tied to individual staff
- `Appointment` is the core booking record: `belongs_to :patient` (User), `:clinic`, `:service`, and optional `:staff` (User). Uses `starts_at`/`ends_at` datetimes rather than fixed slot indices, so services of different durations can be booked against the same calendar.

**Double-booking prevention lives in `Appointment#no_overlapping_appointments`** (model-level validation, not a DB constraint): it queries other non-cancelled appointments in the same clinic whose time range intersects the new one, additionally scoped to `staff_id` when one is set. Any change to appointment scheduling logic needs to go through this validation, not around it.

**Testing**: RSpec + FactoryBot (not Minitest, despite `test/` still existing from `rails new` scaffolding — new specs belong in `spec/`). Devise request-spec sign-in helpers are wired in `spec/rails_helper.rb` via `Devise::Test::IntegrationHelpers` for `type: :request`.

**Deployment**: Kamal is scaffolded (`config/deploy.yml`, `.kamal/`) for eventual Docker-based VPS deployment, but Docker cannot run in the current local dev sandbox (no cgroup access) — local development only uses `bin/rails server` directly.
