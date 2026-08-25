// Playwright smoke check for docs/admin_portal/13_reports.md.
// Usage: node e2e/staff_reports.js  (see e2e/README.md for setup)
const { launch, closeAndSaveVideo, signIn } = require("./lib/browser");
const { check, summarize } = require("./lib/check");
const path = require("path");

(async () => {
  const { browser, context, page, consoleErrors, baseUrl, recordingVideo } = await launch();
  const pause = () => page.waitForTimeout(recordingVideo ? 700 : 0);

  await signIn(page, baseUrl, "owner@bookq.test", "password123");
  await pause();

  await page.locator('button[data-action="staff-nav#open"]').first().click();
  await page.waitForTimeout(300);
  await page.click('aside a:has-text("Reports")');
  await page.waitForURL(`${baseUrl}/staff/reports`, { timeout: 10000 });
  await pause();

  check("Reports landing page loads", page.url() === `${baseUrl}/staff/reports`);
  check("shows the 3 ready-now report cards as real links", await page.locator('a[href="/staff/reports/appointments"]').count() === 1
    && await page.locator('a[href="/staff/reports/patients"]').count() === 1
    && await page.locator('a[href="/staff/reports/services"]').count() === 1);
  check("Inventory Report is shown but disabled (not a dead link)", (await page.locator("body").innerText()).includes("Inventory Report")
    && await page.locator('a:has-text("Inventory Report")').count() === 0);

  // Appointments report.
  await page.click('a[href="/staff/reports/appointments"]');
  await page.waitForURL(`${baseUrl}/staff/reports/appointments`, { timeout: 10000 });
  await pause();
  check("Appointments Report loads with a Total figure", (await page.locator("body").innerText()).includes("Total Appointments"));

  await page.click('a:has-text("Last Month")');
  await page.waitForURL(/period=last_month/, { timeout: 10000 });
  await pause();
  check("period pill actually changes the URL/query range", page.url().includes("period=last_month"));

  // Patient report.
  await page.goto(`${baseUrl}/staff/reports/patients`);
  await pause();
  check("Patient Report loads with New/Returning counts", (await page.locator("body").innerText()).includes("New Patients")
    && (await page.locator("body").innerText()).includes("Returning Patients"));

  // Services report.
  await page.goto(`${baseUrl}/staff/reports/services`);
  await pause();
  check("Services Report loads", page.url() === `${baseUrl}/staff/reports/services`);
  check("no <select> tags anywhere (radio-card/pill convention)", await page.locator("select").count() === 0);

  check("no browser console/page errors", consoleErrors.length === 0);
  if (consoleErrors.length > 0) console.log("  console errors:", consoleErrors);

  const screenshotPath = path.join(__dirname, "screenshots", "staff_reports.png");
  await page.screenshot({ path: screenshotPath, fullPage: true });
  console.log(`  screenshot saved to ${screenshotPath}`);
  await pause();

  const videoPath = await closeAndSaveVideo(browser, context, "staff_reports");
  if (videoPath) console.log(`  video saved to ${videoPath}`);
  summarize("staff_reports.js");
})();
