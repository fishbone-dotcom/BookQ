# BookQ e2e checks

Playwright smoke checks that run against a real, running `bin/rails server` —
for things RSpec request specs can't see: actual rendering, compiled CSS,
client-side JS behavior, and console errors. One script per page, matching
`docs/admin_portal/`'s per-page workflow.

## Setup (one time)

This sandbox's OS is Alpine (musl libc), which Playwright's own bundled
Chromium download doesn't support. Use the system package instead:

```bash
apk add --no-cache chromium chromium-chromedriver
cd e2e && npm install
```

On a normal Linux/macOS dev machine, skip the `apk add` and instead run
`npx playwright install chromium` once, then unset `CHROMIUM_PATH` (see below)
so it uses Playwright's own browser.

**The Tailwind watcher (`bin/rails tailwindcss:watch`) does not stay running
in this sandbox** (it exits almost immediately — looks like restricted
inotify). If a check fails on layout/spacing that looks fine in the source,
rebuild first: `bin/rails tailwindcss:build`.

## Running a check

```bash
bin/rails server -b 0.0.0.0 -p 3000   # in one terminal
cd e2e && node staff_dashboard.js      # in another
```

Each script prints `ok`/`FAIL` per assertion, exits non-zero if anything
failed, and saves a full-page screenshot to `e2e/screenshots/` for visual
review (gitignored — screenshots are a debugging aid, not committed).

Env vars:
- `BASE_URL` — defaults to `http://localhost:3000`
- `CHROMIUM_PATH` — defaults to `/usr/bin/chromium`; unset/override on a
  machine using Playwright's own downloaded browser instead

## Adding a check for a new page

Copy `staff_dashboard.js` as a starting point. Use `lib/browser.js` for
launching + signing in, and `lib/check.js` for the `check()`/`summarize()`
pass-fail helpers — keep new scripts using the same two so failures read the
same way across pages.
