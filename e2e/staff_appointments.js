// Playwright smoke check for docs/admin_portal/09_appointments_list.md.
// Usage: node e2e/staff_appointments.js  (see e2e/README.md for setup)
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

  check("navigating from the bottom tab lands on /staff/appointments", page.url().startsWith(`${baseUrl}/staff/appointments`));
  check("header shows 'Appointments'", await page.locator("h1", { hasText: "Appointments" }).count() > 0);
  check("bottom tab bar highlights Appointments as active", await page.locator('nav a[href^="/staff/appointments"].text-emerald-700').count() > 0);

  const statusChips = [ "All", "Confirmed", "Pending", "Cancelled" ];
  for (const chip of statusChips) {
    check(`status filter chip "${chip}" is present`, await page.locator(`a:has-text("${chip}")`).count() > 0);
  }

  check("week day strip shows 7 days", await page.locator('a[href*="/staff/appointments?date="]').count() >= 7);

  // Switch to the Cancelled filter and confirm the URL/param actually changed
  // (not just a visual toggle — this is the doc's #1 acceptance item).
  await page.click('a:has-text("Cancelled")');
  await page.waitForLoadState("networkidle");
  await page.waitForTimeout(300);
  await pause();
  check("clicking a filter chip updates the status query param", page.url().includes("status=cancelled"));
  check("Cancelled chip is visually active after selecting it", await page.locator('a:has-text("Cancelled").bg-emerald-600').count() > 0);

  // Navigating a day preserves the status filter (acceptance checklist item #2).
  const firstDayLink = page.locator('a[href*="/staff/appointments?date="]').first();
  const href = await firstDayLink.getAttribute("href");
  check("day strip links preserve the active status filter", href.includes("status=cancelled"));
  await pause();

  check("no browser console/page errors", consoleErrors.length === 0);
  if (consoleErrors.length > 0) console.log("  console errors:", consoleErrors);

  const screenshotPath = path.join(__dirname, "screenshots", "staff_appointments.png");
  await page.screenshot({ path: screenshotPath, fullPage: true });
  console.log(`  screenshot saved to ${screenshotPath}`);
  await pause();

  const videoPath = await closeAndSaveVideo(browser, context, "staff_appointments");
  if (videoPath) console.log(`  video saved to ${videoPath}`);
  summarize("staff_appointments.js");
})();
