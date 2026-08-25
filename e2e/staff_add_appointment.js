// Playwright smoke check for docs/admin_portal/10_add_appointment.md.
// Usage: node e2e/staff_add_appointment.js  (see e2e/README.md for setup)
//
// Uses a dedicated e2e.patient@bookq.test fixture (see the `bin/rails runner`
// snippet in the commit that added this file) so it never collides with real
// demo data, and cancels the booking it creates at the end so the script is
// safely re-runnable.
const { launch, closeAndSaveVideo, signIn } = require("./lib/browser");
const { check, summarize } = require("./lib/check");
const path = require("path");

function nextMonday() {
  const d = new Date();
  d.setDate(d.getDate() + ((8 - d.getDay()) % 7 || 7));
  return d.toISOString().slice(0, 10);
}

(async () => {
  const { browser, context, page, consoleErrors, baseUrl, recordingVideo } = await launch();
  const pause = () => page.waitForTimeout(recordingVideo ? 700 : 0);
  const date = nextMonday();

  await signIn(page, baseUrl, "owner@bookq.test", "password123");
  await pause();

  await page.goto(`${baseUrl}/staff/appointments/new`);
  await page.waitForLoadState("networkidle");
  check("Add Appointment page loads", page.url().startsWith(`${baseUrl}/staff/appointments/new`));
  check("no doctor/staff/patient/service <select> tags (matches this app's radio-card convention)", await page.locator("select").count() === 0);
  await pause();

  // Pick a service — triggers a GET auto-submit reload.
  await page.click('label:has-text("General Check-up")');
  await page.waitForLoadState("networkidle");
  await page.waitForTimeout(300);
  await pause();
  check("selecting a service reloads with service_id set", page.url().includes("service_id="));

  // Pick a date — also auto-submits.
  await page.fill('input[type="date"]', date);
  await page.waitForLoadState("networkidle");
  await page.waitForTimeout(300);
  await pause();
  check("selecting a date reloads with the date set, service still selected", page.url().includes(`date=${date}`) && page.url().includes("service_id="));

  // Search + select the patient.
  await page.fill('input[placeholder="Search patients..."]', "E2E Test");
  await page.waitForTimeout(200);
  await pause();
  check("patient search filters the list", await page.locator('label:has-text("E2E Test Patient")').isVisible());
  await page.click('label:has-text("E2E Test Patient")');
  await pause();

  // Pick a doctor.
  await page.click('label:has-text("Dr. Maria Santos")');
  await pause();

  // Pick the first available time slot.
  const firstSlot = page.locator('input[name="starts_at"]').first();
  const slotCount = await firstSlot.count();
  check("at least one open time slot is offered", slotCount > 0);
  await firstSlot.locator("xpath=..").click();
  await pause();

  await page.fill('textarea[name="notes"]', "Booked by the e2e smoke check");
  await pause();

  await page.click('input[type="submit"][value="Save Appointment"]');
  await page.waitForLoadState("networkidle");
  await page.waitForTimeout(300);
  await pause();

  check("saving redirects to the Appointments list for that date", page.url().startsWith(`${baseUrl}/staff/appointments`) && page.url().includes(`date=${date}`));
  const bodyText = await page.locator("body").innerText();
  check("success notice names the patient", bodyText.includes("E2E Test Patient"));
  check("new appointment appears in the day's list", bodyText.includes("General Check-up"));

  check("no browser console/page errors", consoleErrors.length === 0);
  if (consoleErrors.length > 0) console.log("  console errors:", consoleErrors);

  const screenshotPath = path.join(__dirname, "screenshots", "staff_add_appointment.png");
  await page.screenshot({ path: screenshotPath, fullPage: true });
  console.log(`  screenshot saved to ${screenshotPath}`);
  await pause();

  // Cleanup so the fixture patient is free again for the next run.
  await page.locator('button[data-action="staff-nav#open"]').first().click();
  await page.waitForTimeout(300);
  await page.click('button:has-text("Log out")');
  await page.waitForLoadState("networkidle");
  await signIn(page, baseUrl, "e2e.patient@bookq.test", "password123");
  const viewAppt = page.locator("text=View Appointment");
  if (await viewAppt.count()) {
    await viewAppt.click();
    await page.waitForLoadState("networkidle");
    await page.click('button:has-text("Cancel booking")');
    await page.waitForTimeout(300);
    await page.click('[data-choice="ok"]');
    await page.waitForLoadState("networkidle");
    console.log("  cleanup: cancelled the test booking so the fixture patient is free again");
  }

  const videoPath = await closeAndSaveVideo(browser, context, "staff_add_appointment");
  if (videoPath) console.log(`  video saved to ${videoPath}`);
  summarize("staff_add_appointment.js");
})();
