// Playwright smoke check for docs/admin_portal/03_doctors_list.md.
// Usage: node e2e/staff_doctors.js  (see e2e/README.md for setup)
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
  await page.click('aside a:has-text("Doctors")');
  await page.waitForURL(`${baseUrl}/staff/doctors`, { timeout: 10000 });
  await pause();

  check("Doctors page loads at the right URL", page.url() === `${baseUrl}/staff/doctors`);
  check("header shows 'Doctors'", await page.locator("h1", { hasText: "Doctors" }).count() > 0);
  check("shows the clinic owner with their specialization", (await page.locator("body").innerText()).includes("General Practitioner"));
  check("Available badge renders green", await page.locator("span", { hasText: "Available" }).first().getAttribute("class").then((c) => c.includes("bg-green-50")));
  check("On Leave badge renders amber", await page.locator("span", { hasText: "On Leave" }).first().getAttribute("class").then((c) => c.includes("bg-amber-50")));

  // Live search filter.
  const searchBox = page.locator('input[placeholder="Search doctors..."]');
  await searchBox.fill("zzz-no-match");
  await page.waitForTimeout(150);
  check('search filters out non-matching doctors ("No doctors found.")', await page.locator("text=No doctors found.").isVisible());
  await pause();
  await searchBox.fill("pediatric");
  await page.waitForTimeout(150);
  await pause();

  check("Add Doctor button links to the new-doctor form (owner)", await page.locator('a[href="/staff/doctors/new"]').count() > 0);

  check("no browser console/page errors", consoleErrors.length === 0);
  if (consoleErrors.length > 0) console.log("  console errors:", consoleErrors);

  await searchBox.fill("");
  await page.waitForTimeout(150);
  const screenshotPath = path.join(__dirname, "screenshots", "staff_doctors.png");
  await page.screenshot({ path: screenshotPath, fullPage: true });
  console.log(`  screenshot saved to ${screenshotPath}`);
  await pause();

  const videoPath = await closeAndSaveVideo(browser, context, "staff_doctors");
  if (videoPath) console.log(`  video saved to ${videoPath}`);
  summarize("staff_doctors.js");
})();
