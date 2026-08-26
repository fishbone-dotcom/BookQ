// Full end-to-end demo of BookQ in one continuous Playwright session/video:
// patient-side booking flow, then a tour of the whole staff admin console.
// This is a WALKTHROUGH, not an exhaustive regression suite — each feature
// already has its own dedicated e2e script with deep checks (staff_*.js,
// devise_edit_profile.js). This script's job is to show the whole app
// working together in one recording, with light sanity checks along the way.
//
// Creates a throwaway demo patient via `bin/rails runner` (the seeded
// patient@bookq.test already has active bookings from db/seeds.rb, so a
// fresh account is needed to demo the booking wizard cleanly), cleaned up
// in a `finally` block.
// Usage: node e2e/full_demo.js  (add RECORD_VIDEO=1 for a video)
const { execSync } = require("child_process");
const { launch, closeAndSaveVideo, signIn } = require("./lib/browser");
const { check, summarize } = require("./lib/check");
const path = require("path");

const stamp = Date.now();
const patientEmail = `e2e-full-demo-patient-${stamp}@example.com`;

function setup() {
  const setupScript = `
    User.create!(email: "${patientEmail}", password: "password123", password_confirmation: "password123", role: :patient, name: "Demo Walkthrough Patient")
    puts "OK"
  `;
  execSync(`cd .. && bin/rails runner '${setupScript}'`, { encoding: "utf8" });
}

function cleanup() {
  try {
    execSync(`cd .. && bin/rails runner 'User.find_by(email: "${patientEmail}")&.destroy'`, { stdio: "pipe" });
    console.log("  cleanup: removed the throwaway demo patient");
  } catch (e) {
    console.log("  cleanup warning: could not remove throwaway demo patient —", e.message);
  }
}

(async () => {
  setup();
  const { browser, context, page, consoleErrors, baseUrl, recordingVideo } = await launch();
  const pause = (ms) => page.waitForTimeout(ms ?? (recordingVideo ? 900 : 0));

  try {
    // ======================================================================
    // PART 1 — Patient side: sign up flow already exists, so start signed in
    // and walk through booking an appointment, then cancelling it.
    // ======================================================================
    console.log("\n=== PART 1: Patient booking flow ===");
    console.log(`→ signing in as patient (${patientEmail})`);
    await signIn(page, baseUrl, patientEmail, "password123");
    await pause();
    check("patient home page loads", page.url() === `${baseUrl}/`);
    check("shows 'no upcoming appointment' before booking", (await page.locator("body").innerText()).includes("don't have an upcoming appointment"));

    console.log("→ opening a clinic's booking wizard");
    await page.locator('a[href^="/clinics/"]').first().click();
    await page.waitForURL(/\/clinics\/\d+\/booking/, { timeout: 10000 });
    await pause();
    check("booking wizard step 1 (Service) loads", (await page.locator("body").innerText()).includes("Service"));

    // Step 1: pick the first service, submit the GET form (reloads with service_id, auto-advances to step 2).
    console.log("→ step 1/4: picking a service");
    await page.locator('label:has(input[name="service_id"])').first().click();
    await pause();
    await page.click('button[data-booking-wizard-target="nextButton"]');
    await page.waitForURL(/service_id=\d+/, { timeout: 10000 });
    await pause();
    check("advanced to step 2 (Doctor) after picking a service", await page.locator('[data-booking-wizard-target="stepPanel"][data-step="2"]').isVisible());

    // Step 2: leave "Anyone / No preference" selected (default), just advance
    // (client-side only via Stimulus — no navigation, no URL change).
    console.log("→ step 2/4: leaving doctor as 'Anyone / No preference'");
    await page.click('button[data-booking-wizard-target="nextButton"]');
    await pause();
    check("advanced to step 3 (Schedule)", await page.locator('[data-booking-wizard-target="stepPanel"][data-step="3"]').isVisible());

    // Step 3: pick the first date with green (available) slots, then a time.
    // The date cell is a turbo-frame link (data-turbo-frame="slots") — it does
    // NOT change the browser URL, it swaps content inside the frame, so wait
    // for the time-slot radios to actually appear instead of for a URL/load event.
    console.log("→ step 3/4: picking the first available date + time slot");
    const availableDate = page.locator('[data-booking-wizard-target="dateCell"]').filter({ has: page.locator(".avail-dot.bg-green-500") }).first();
    await availableDate.waitFor({ state: "visible", timeout: 10000 });
    await availableDate.click();
    await page.locator('input[name="starts_at"]').first().waitFor({ state: "attached", timeout: 10000 });
    await pause();
    await page.locator('label:has(input[name="starts_at"])').first().click();
    await pause();
    check("Next enables once a date and time are both picked", await page.locator('button[data-booking-wizard-target="nextButton"]').isEnabled());
    await page.click('button[data-booking-wizard-target="nextButton"]');
    await pause();
    check("advanced to step 4 (Confirm) with a filled-in summary", (await page.locator("body").innerText()).includes("Review before confirming"));

    // Step 4: submit the booking.
    console.log("→ step 4/4: confirming the booking");
    await page.click('input[type="submit"]');
    await page.waitForURL(`${baseUrl}/`, { timeout: 10000 });
    await pause();
    check("booking confirmed, back on home with the new appointment showing", (await page.locator("body").innerText()).includes("View Appointment"));

    // Cancel it, back to a clean state.
    console.log("→ cancelling the appointment to reset to a clean state");
    await page.click("text=View Appointment");
    await page.waitForURL(/\/clinics\/\d+\/booking/, { timeout: 10000 });
    await pause();
    await page.click('button:has-text("Cancel booking")');
    await page.locator('button[data-choice="ok"]').waitFor({ timeout: 5000 });
    await pause();
    await page.click('button[data-choice="ok"]');
    await page.waitForURL(`${baseUrl}/`, { timeout: 10000 });
    await pause();
    check("cancelling returns home with the upcoming-appointment slot cleared again", (await page.locator("body").innerText()).includes("don't have an upcoming appointment"));

    console.log("→ logging out of the patient account");
    await page.locator('button:has-text("Log out")').click();
    await page.waitForURL(`${baseUrl}/`, { timeout: 10000 });
    await pause();

    // ======================================================================
    // PART 2 — Staff side: tour the whole admin console as the clinic owner.
    // ======================================================================
    console.log("\n=== PART 2: Staff admin console tour ===");
    console.log("→ signing in as clinic owner (owner@bookq.test)");
    await signIn(page, baseUrl, "owner@bookq.test", "password123");
    await pause();
    check("staff sign-in lands on the Staff Dashboard", page.url() === `${baseUrl}/staff/dashboard`);
    check("Dashboard shows the stat cards", (await page.locator("body").innerText()).includes("Total Patients"));

    const openDrawer = async () => {
      await page.locator('button[data-action="staff-nav#open"]').first().click();
      await page.waitForTimeout(300);
    };

    // Appointments — list + calendar toggle.
    console.log("→ Appointments: list view");
    await openDrawer();
    await Promise.all([ page.waitForURL(`${baseUrl}/staff/appointments`, { timeout: 10000 }), page.click('aside a:has-text("Appointments")') ]);
    await pause();
    check("Appointments list loads", (await page.locator("body").innerText()).includes("Appointments"));
    console.log("→ Appointments: calendar view");
    await Promise.all([ page.waitForURL(/\/staff\/calendar/, { timeout: 10000 }), page.click('a:has-text("Calendar")') ]);
    await pause();
    check("Calendar View loads", page.url().includes("/staff/calendar"));

    // Doctors.
    console.log("→ Doctors list");
    await openDrawer();
    await Promise.all([ page.waitForURL(`${baseUrl}/staff/doctors`, { timeout: 10000 }), page.click('aside a:has-text("Doctors")') ]);
    await pause();
    check("Doctors list loads", (await page.locator("body").innerText()).includes("Doctors"));

    // Patients + a patient's profile.
    console.log("→ Patients list");
    await openDrawer();
    await Promise.all([ page.waitForURL(`${baseUrl}/staff/patients`, { timeout: 10000 }), page.click('aside a:has-text("Patients")') ]);
    await pause();
    check("Patients list loads", (await page.locator("body").innerText()).includes("Patients"));
    const patientRow = page.locator('a[href^="/staff/patients/"]').first();
    if (await patientRow.count() > 0) {
      console.log("→ opening a Patient Profile");
      await patientRow.click();
      await page.waitForURL(/\/staff\/patients\/\d+$/, { timeout: 10000 });
      await pause();
      check("Patient Profile loads with tabs", (await page.locator("body").innerText()).includes("Personal Information"));
    }

    // Reports — landing + the 3 built reports.
    console.log("→ Reports landing");
    await openDrawer();
    await Promise.all([ page.waitForURL(`${baseUrl}/staff/reports`, { timeout: 10000 }), page.click('aside a:has-text("Reports")') ]);
    await pause();
    check("Reports landing loads", (await page.locator("body").innerText()).includes("Appointments Report"));
    for (const [ label, path ] of [
      [ "Appointments Report", "/staff/reports/appointments" ],
      [ "Patient Report", "/staff/reports/patients" ],
      [ "Services Report", "/staff/reports/services" ],
    ]) {
      console.log(`→ Reports: ${label}`);
      await page.goto(`${baseUrl}/staff/reports`);
      await page.waitForURL(`${baseUrl}/staff/reports`, { timeout: 10000 });
      await page.click(`a:has-text("${label}")`);
      await page.waitForURL(`${baseUrl}${path}`, { timeout: 10000 });
      await pause();
      check(`${label} page loads`, (await page.locator("body").innerText()).length > 0);
    }

    // Settings — landing + Clinic Info + Working Hours + Users & Roles (view only, no saves).
    console.log("→ Settings landing");
    await openDrawer();
    await Promise.all([ page.waitForURL(`${baseUrl}/staff/settings`, { timeout: 10000 }), page.click('aside a:has-text("Settings")') ]);
    await pause();
    check("Settings landing loads", (await page.locator("body").innerText()).includes("Clinic Information"));

    console.log("→ Settings: Clinic Information");
    await page.click('a[href="/staff/settings/clinic"]');
    await page.waitForURL(`${baseUrl}/staff/settings/clinic`, { timeout: 10000 });
    await pause();
    check("Clinic Information page loads", await page.locator('input[name="clinic[name]"]').count() === 1);

    console.log("→ Settings: Working Hours");
    await page.goto(`${baseUrl}/staff/settings`);
    await page.click('a[href="/staff/settings/hours"]');
    await page.waitForURL(`${baseUrl}/staff/settings/hours`, { timeout: 10000 });
    await pause();
    check("Working Hours page loads", (await page.locator("body").innerText()).includes("Sunday"));

    console.log("→ Settings: Users & Roles");
    await page.goto(`${baseUrl}/staff/settings`);
    await page.click('a[href="/staff/clinic_staffs"]');
    await page.waitForURL(`${baseUrl}/staff/clinic_staffs`, { timeout: 10000 });
    await pause();
    check("Users & Roles page loads", (await page.locator("body").innerText()).includes("You"));

    // Profile / Change Password.
    console.log("→ Profile page");
    await page.goto(`${baseUrl}/staff/settings`);
    await page.click('a[href="/users/edit"]');
    await page.waitForURL(`${baseUrl}/users/edit`, { timeout: 10000 });
    await pause();
    check("Profile page loads", (await page.locator("body").innerText()).includes("Profile"));
    console.log("→ Change Password page");
    await page.click('a[href="/users/change_password"]');
    await page.waitForURL(`${baseUrl}/users/change_password`, { timeout: 10000 });
    await pause();
    check("Change Password page loads", (await page.locator("body").innerText()).includes("Change Password"));

    console.log("\n=== Wrap-up ===");
    check("no browser console/page errors across the whole tour", consoleErrors.length === 0);
    if (consoleErrors.length > 0) console.log("  console errors:", consoleErrors);

    const screenshotPath = path.join(__dirname, "screenshots", "full_demo_final.png");
    await page.screenshot({ path: screenshotPath, fullPage: true });
    console.log(`  screenshot saved to ${screenshotPath}`);
    await pause();

    const videoPath = await closeAndSaveVideo(browser, context, "full_demo");
    if (videoPath) console.log(`  video saved to ${videoPath}`);
  } finally {
    await browser.close().catch(() => {});
    cleanup();
  }

  summarize("full_demo.js");
})();
