---
name: e2e-check
description: Write or run a Playwright browser check against the local BookQ Rails server in this sandbox — real-browser verification RSpec can't do (actual rendering, compiled CSS, client-side JS, console errors). Use whenever asked to verify a page visually, check for errors in the browser, record a demo video, or add/run a script under e2e/.
---

# Playwright e2e Checks (this sandbox)

`e2e/` holds small Node/Playwright scripts, one per staff-portal page, that
drive a real headless browser against `bin/rails server` — for the class of
bug RSpec request specs structurally can't see (Tailwind not rebuilt, a JS
controller not wiring up, a Turbo navigation quietly failing, console errors).
Full usage/setup is in `e2e/README.md`; this skill covers the sandbox-specific
gotchas that aren't obvious from that file alone.

## Environment (read this before debugging a weird failure)

This sandbox is **Alpine Linux (musl libc)**, which Playwright's own bundled
Chromium download does not support (`npx playwright install chromium` will
fetch a glibc build that fails to run here). Use the system package instead —
already installed in this repo's sandbox, but if a fresh environment doesn't
have it:

```bash
apk add --no-cache chromium chromium-chromedriver
cd e2e && npm install   # installs playwright-core, not the full playwright package
```

Every script launches via `executablePath: process.env.CHROMIUM_PATH ||
"/usr/bin/chromium"` (see `e2e/lib/browser.js`) — never `playwright`'s own
`chromium.launch()` default path in this sandbox.

**The Tailwind watcher does not survive here.** `bin/rails tailwindcss:watch`
exits almost immediately with no error (looks like restricted inotify). If an
e2e check fails on something that looks like broken/missing styling (an
element in the wrong position, a class with no visible effect), rebuild
first: `bin/rails tailwindcss:build`. This has been the actual cause more
than once — rule it out before assuming the check or the app logic is wrong.

**Cold-start flakiness**: the very first request to a route/controller Rails
hasn't autoloaded yet in this dev process can be slow enough to fail an
assertion on a tight timeout. If a script fails on its first run after adding
a new page, re-run it once before concluding there's a real bug.

## Running a check

```bash
bin/rails server -b 0.0.0.0 -p 3000   # if not already running
cd e2e && node staff_dashboard.js      # or whichever script
```

Each script prints `ok`/`FAIL` per assertion and exits non-zero on any
failure. Screenshots always save to `e2e/screenshots/` (gitignored).

## Writing a new check

Copy an existing script (`staff_calendar.js` is a good template — covers a
GET page, a state toggle, and an empty state) rather than starting from
scratch. Use `lib/browser.js`'s `launch()`/`signIn()` and `lib/check.js`'s
`check()`/`summarize()` so failures read the same way across every script.
Seeded accounts to sign in as: `owner@bookq.test` / `doctor@bookq.test`
(clinic staff, password `password123`), `patient@bookq.test` (patient role).

If a check needs to create data (an appointment, a second clinic) and isn't
naturally idempotent, either:

- create a **dedicated fixture user** for that script (e.g.
  `e2e.patient@bookq.test`, see `staff_add_appointment.js`) so it never
  collides with real demo data the user is looking at, and
- **clean up at the end of the script** (cancel the booking it created) so
  the script is safely re-runnable without manual DB resets between runs.

A Turbo-intercepted click that should navigate but the page state doesn't
visibly update (e.g. logging out) can mean the target action doesn't handle
the `turbo_stream` format Turbo requests — check `log/development.log` for
what format the request actually landed as before assuming the click
selector is wrong.

## Recording and sending a video to the user

```bash
RECORD_VIDEO=1 node staff_calendar.js
```

Saves `e2e/videos/<script-name>.webm` (gitignored) and inserts short pauses
between steps so it's actually watchable. Convert to mp4 before sending —
`.webm` doesn't play reliably in every phone gallery/player:

```bash
ffmpeg -y -i e2e/videos/staff_calendar.webm -c:v libx264 -pix_fmt yuv420p \
  -movflags +faststart e2e/videos/staff_calendar.mp4
```

To actually deliver a screenshot or video to the user on this device, copy it
into their Downloads folder first, then send it — a file card alone from a
path under `e2e/` or the scratchpad isn't reliably visible/playable to them:

```bash
cp e2e/videos/staff_calendar.mp4 /sdcard/Download/staff_calendar.mp4
```

Then use the `SendUserFile` tool with that `/sdcard/Download/...` path.
