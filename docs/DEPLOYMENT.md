# BookQ Developer Setup & Deployment Guide

This app runs locally with a plain `bin/rails server` and deploys to
production as a Docker container via **Kamal** (already scaffolded in
`config/deploy.yml` and `.kamal/`). Production needs no separate app-server/
DB-server split — Rails 8's Solid Queue, Solid Cache, and Solid Cable all
run inside the one container, backed by SQLite files on a persistent
volume.

---

# Part 1 — Local Development Setup

## 1.1 Prerequisites

- [ ] **Ruby 3.3.10** (see `.ruby-version`) — install via rbenv, rvm, asdf,
      or mise.
- [ ] **SQLite3** installed on the system (needed to build the `sqlite3`
      gem) — `apt install sqlite3 libsqlite3-dev` / `brew install sqlite3`.
- [ ] **libvips** — used by Active Storage for image processing
      (`apt install libvips` / `brew install vips`).
- [ ] `bundle` (comes with Ruby) — no Node.js/npm is required for the main
      app; Tailwind is compiled via the `tailwindcss-rails` gem, not a JS
      toolchain.
- [ ] `config/master.key` — decrypts `config/credentials.yml.enc`. This
      file is gitignored on purpose and is **not** in the repo. Get a copy
      from an existing developer or from wherever the team stores secrets
      (password manager); do not generate a new one on top of an existing
      `credentials.yml.enc` or you'll lock everyone else out. If you're
      bootstrapping this project fresh with no existing credentials file,
      running `bin/rails credentials:edit` will generate both files together.

## 1.2 First-time setup

```bash
git clone <repo-url>
cd BookQ
bin/setup
```

`bin/setup` bundles gems, prepares the dev + test databases, clears old
logs/tmp files, and then launches `bin/dev`. Equivalent manual steps if you
want to run them yourself:

```bash
bundle install
bin/rails db:prepare        # creates + migrates storage/development.sqlite3
bin/rails db:test:prepare   # syncs the test DB schema
```

### Load demo data (optional)

```bash
bin/rails db:seed
```

Seeds are idempotent (`db/seeds.rb`) and create a demo clinic owner, staff
doctor, and patient, plus a couple of demo appointments — useful for
manually exercising the booking flow and the appointment-reminder emails.
Login credentials for all seeded accounts are `password123` (see the file
for exact emails).

## 1.3 Running the app

```bash
bin/dev
```

Runs `Procfile.dev`: the Rails server (`bin/rails server`) and the Tailwind
watcher (`bin/rails tailwindcss:watch`) together. Visit
`http://localhost:3000`.

If you only need the server (e.g. the Tailwind watcher won't stay running
in some restricted/containerized shells — it exits almost immediately),
run `bin/rails server -b 0.0.0.0 -p 3000` directly and rebuild CSS on
demand with `bin/rails tailwindcss:build`.

## 1.4 Running tests and checks

```bash
bundle exec rspec                                   # full suite
bundle exec rspec spec/models/appointment_spec.rb    # one file
bundle exec rspec spec/models/appointment_spec.rb:12  # one example

bin/rubocop      # lint (rubocop-rails-omakase)
bin/brakeman     # security static analysis
```

Whenever you pull migrations, re-run `bin/rails db:migrate` then
`bin/rails db:test:prepare` before running specs.

### Browser (e2e) checks

`e2e/` has Playwright scripts that check real rendering/JS behavior against
a running server (RSpec can't see compiled CSS or console errors). One-time
setup:

```bash
cd e2e && npm install
npx playwright install chromium   # skip if using a system chromium
```

Then, with `bin/rails server -b 0.0.0.0 -p 3000` running in one terminal:

```bash
cd e2e && node staff_dashboard.js   # or full_demo.js, etc.
```

See `e2e/README.md` for environment variables and sandbox-specific notes.

## 1.5 Useful local commands

```bash
bin/rails console       # REPL against the dev DB
bin/rails db:reset      # drop, recreate, migrate, seed
bin/rails routes        # list all routes
```

---

# Part 2 — Production Deployment

> **Important:** Docker cannot run inside a restricted CI/agent sandbox
> without cgroup access. Production deploys must be run from a real
> machine (a developer's laptop, or a CI runner) that has Docker installed
> and network access to the target server. This part assumes you are
> running these commands from such a machine, with this repo checked out.

## 2.1 Prerequisites

- [ ] A Linux VPS with a public IP and root (or sudo) SSH access — e.g.
      DigitalOcean, Hetzner, Linode, AWS Lightsail. 1 vCPU / 1–2 GB RAM is
      enough to start.
- [ ] Docker installed **locally**, on the machine you run `bin/kamal` from
      (Kamal builds the image on your machine, not the server).
- [ ] SSH key-based login to the server already working
      (`ssh root@your-server-ip` with no password prompt).
- [ ] A container registry account to store the built image — Docker Hub is
      the simplest (free for public/small private repos). GHCR also works.
- [ ] (Strongly recommended) A domain name, with its DNS `A` record pointed
      at the server's IP. Needed for HTTPS and for correct links in
      appointment-reminder emails.
- [ ] An SMTP provider for outgoing mail (Postmark, SendGrid, Mailgun,
      Amazon SES, etc.) — required for the appointment reminder emails and
      Devise account emails to actually deliver.
- [ ] Your local `config/master.key` (see 1.1 above). Back it up somewhere
      safe (password manager); if you lose it, production secrets become
      unrecoverable and you'd have to rotate `config/credentials.yml.enc`
      from scratch.

## 2.2 One-time setup

### 2.2.1 Point DNS at the server

Create an `A` record for your domain (e.g. `app.yourclinic.com`) pointing
to the VPS's IP address. Give it a few minutes to propagate before
deploying.

### 2.2.2 Log in to your container registry locally

```bash
docker login                 # Docker Hub
# or: docker login ghcr.io   # GitHub Container Registry
```

### 2.2.3 Add SMTP credentials to Rails credentials

```bash
EDITOR="nano" bin/rails credentials:edit
```

Add:

```yaml
smtp:
  user_name: your_smtp_username
  password: your_smtp_password
  address: smtp.yourprovider.com
  port: 587
```

### 2.2.4 Configure `config/environments/production.rb`

A few lines are commented out by default and need to be turned on before a
real deploy:

```ruby
# Terminate SSL at Kamal's built-in proxy, force HTTPS everywhere:
config.assume_ssl = true
config.force_ssl = true

# Real outgoing mail, not the default no-op:
config.action_mailer.raise_delivery_errors = true
config.action_mailer.default_url_options = { host: "app.yourclinic.com" }
config.action_mailer.smtp_settings = {
  user_name: Rails.application.credentials.dig(:smtp, :user_name),
  password: Rails.application.credentials.dig(:smtp, :password),
  address: Rails.application.credentials.dig(:smtp, :address),
  port: Rails.application.credentials.dig(:smtp, :port),
  authentication: :plain
}
config.action_mailer.delivery_method = :smtp

# Lock down which Host headers are accepted:
config.hosts << "app.yourclinic.com"
config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
```

Commit these changes — they're app config, not secrets.

### 2.2.5 Configure `config/deploy.yml`

Edit the placeholders:

```yaml
servers:
  web:
    - YOUR_SERVER_IP        # replace 192.168.0.1

registry:
  server: docker.io         # or ghcr.io — omit entirely for Docker Hub
  username: your-registry-username
  password:
    - KAMAL_REGISTRY_PASSWORD   # pulled from .kamal/secrets / ENV, not hardcoded

proxy:
  ssl: true
  host: app.yourclinic.com  # enables Kamal's automatic Let's Encrypt cert
```

### 2.2.6 Set the registry password secret

`.kamal/secrets` already reads `RAILS_MASTER_KEY` from `config/master.key`
automatically — nothing to change there. Add your registry password as an
environment variable before deploying (don't put raw passwords in the repo):

```bash
export KAMAL_REGISTRY_PASSWORD=your_docker_hub_access_token
```

Use an access token, not your actual account password, if your registry
supports it (Docker Hub does, under Account Settings → Security).

## 2.3 First deploy

```bash
bin/kamal setup
```

This builds the image, provisions Docker + the Kamal proxy on the server,
pushes the image, and starts the container. It also runs
`bin/rails db:prepare` automatically on boot (see
`bin/docker-entrypoint`), so migrations and the SQLite files are created on
first launch.

Confirm it's live:

```bash
bin/kamal app logs
curl -I https://app.yourclinic.com/up
```

**Do not run `db:seed` in production** — `db/seeds.rb` creates demo
patients/appointments for local development only.

## 2.4 Routine deploys

For every subsequent release:

```bash
git pull                 # make sure you're deploying what you think you are
bin/kamal deploy
```

This rebuilds the image, pushes it, and does a rolling restart with zero
downtime (old container keeps serving until the new one passes its health
check on `/up`).

## 2.5 Data & backups

Production data lives entirely in SQLite files on the `book_q_storage`
Docker volume (`storage/production*.sqlite3` — primary DB, cache, queue,
and cable databases, plus any uploaded Active Storage files). This volume
is **not** backed up automatically. At minimum:

- Set up a cron job on the server to periodically copy the volume's
  contents off-box (e.g. `docker run --rm -v book_q_storage:/data -v
  /backups:/backup alpine tar czf /backup/bookq-$(date +%F).tar.gz /data`),
  pushed somewhere off the server (S3, another host).
- Before any risky deploy or migration, take a manual snapshot.
- If the app grows past a single small clinic's worth of traffic, consider
  moving to a managed Postgres instance instead of file-based SQLite —
  that's a schema/adapter change, not just an infra change.

## 2.6 Useful commands

```bash
bin/kamal app logs -f          # tail logs
bin/kamal console               # Rails console on the server
bin/kamal shell                 # bash shell in the running container
bin/kamal dbc                   # rails dbconsole
bin/kamal app exec "bin/rails db:migrate"   # one-off command
bin/kamal rollback              # roll back to the previous image if a deploy is bad
```

(These aliases are defined in `config/deploy.yml` under `aliases:`.)

## 2.7 Troubleshooting

- **Emails not sending**: check `config.action_mailer.smtp_settings` is
  populated and `bin/kamal app logs` for delivery errors; confirm
  `send_appointment_reminders` recurring job is running
  (`config/recurring.yml`) — `SOLID_QUEUE_IN_PUMA: true` in
  `config/deploy.yml` means the job supervisor runs inside the same
  container as the web process, so if the container is up, jobs should be
  running.
- **502 / container won't start**: `bin/kamal app logs` first; a common
  cause is a missing/incorrect `RAILS_MASTER_KEY` on the server — re-check
  `.kamal/secrets` resolves to the right `config/master.key`.
- **Blocked by Host header**: means `config.hosts` in `production.rb`
  doesn't include the domain you're hitting the server on.
- **Uploaded files / DB missing after a deploy**: confirms the
  `book_q_storage` volume mount in `config/deploy.yml` wasn't
  accidentally removed — it's what makes SQLite data persist across
  container replacements.
