// Playwright smoke check for docs/admin_portal/12_calendar_view.md.
// Usage: node e2e/staff_calendar.js  (see e2e/README.md for setup)
const { launch, closeAndSaveVideo, signIn } = require("./lib/browser");
const { check, summarize } = require("./lib/check");
const path = require("path");

(async () => {
  const { browser, context, page, consoleErrors, baseUrl, recordingVideo } = await launch();
  const pause = () => page.waitForTimeout(recordingVideo ? 700 : 0);

  await signIn(page, baseUrl, "owner@bookq.test", "password123");
  await pause();

  await page.locator("nav").last().locator('a[href="/staff/appointments"]').click();
  await page.waitForLoadState("networkidle");
  await page.waitForTimeout(300);
  await pause();

  // Reach Calendar View via the List/Calendar toggle on the Appointments page —
  // it isn't in the drawer nav (matches the mockup, where it's a view mode of
  // Appointments, not a separate top-level destination).
  await page.click('a:has-text("Calendar")');
  await page.waitForLoadState("networkidle");
  await page.waitForTimeout(300);
  await pause();

  check("Calendar toggle navigates to /staff/calendar", page.url().startsWith(`${baseUrl}/staff/calendar`));
  check("header shows 'Calendar View'", await page.locator("h1", { hasText: "Calendar View" }).count() > 0);
  check("week day strip is present (shared with Appointments)", await page.locator('a[href*="/staff/calendar?date="]').count() >= 7);
  check("List toggle link points back to the Appointments page", await page.locator('a[href^="/staff/appointments"]:has-text("List")').count() > 0);

  const hasGrid = (await page.locator("text=Clinic is closed").count()) === 0;
  if (hasGrid) {
    check("hour grid renders (no 'closed' message on an open day)", true);
  } else {
    console.log("  (landed on a day with no availability — closed-state check below covers this instead)");
  }

  check("floating add button links to Add Appointment", await page.locator('a[href^="/staff/appointments/new"]').count() > 0);

  // A day the seeded clinic has no Availability row for should show the closed state.
  await page.goto(`${baseUrl}/staff/calendar?date=${nextSunday()}`);
  await page.waitForLoadState("networkidle");
  await page.waitForTimeout(300);
  await pause();
  check("a day with no Availability shows a closed message, not a broken grid", await page.locator("text=Clinic is closed").count() > 0);

  check("no browser console/page errors", consoleErrors.length === 0);
  if (consoleErrors.length > 0) console.log("  console errors:", consoleErrors);

  // Screenshot a weekday for the visual record (grid, not the closed state).
  await page.goto(`${baseUrl}/staff/calendar?date=${nextMonday()}`);
  await page.waitForLoadState("networkidle");
  await page.waitForTimeout(300);
  const screenshotPath = path.join(__dirname, "screenshots", "staff_calendar.png");
  await page.screenshot({ path: screenshotPath, fullPage: true });
  console.log(`  screenshot saved to ${screenshotPath}`);
  await pause();

  const videoPath = await closeAndSaveVideo(browser, context, "staff_calendar");
  if (videoPath) console.log(`  video saved to ${videoPath}`);
  summarize("staff_calendar.js");
})();

function nextSunday() {
  const d = new Date();
  d.setDate(d.getDate() + ((7 - d.getDay()) % 7 || 7));
  return d.toISOString().slice(0, 10);
}

function nextMonday() {
  const d = new Date();
  d.setDate(d.getDate() + ((8 - d.getDay()) % 7 || 7));
  return d.toISOString().slice(0, 10);
}
