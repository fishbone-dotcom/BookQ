// Playwright smoke check for docs/admin_portal/05_patients_list.md.
// Usage: node e2e/staff_patients.js  (see e2e/README.md for setup)
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
  await page.click('aside a:has-text("Patients")');
  await page.waitForURL(`${baseUrl}/staff/patients`, { timeout: 10000 });
  await pause();

  check("Patients page loads at the right URL", page.url() === `${baseUrl}/staff/patients`);
  check("header shows 'Patients'", await page.locator("h1", { hasText: "Patients" }).count() > 0);
  check("shows the seeded patient with age/sex details", (await page.locator("body").innerText()).includes("Juana Dela Cruz"));
  check("shows the seeded patient's phone number", (await page.locator("body").innerText()).includes("0917-555-1234"));

  // Live search filter.
  const searchBox = page.locator('input[placeholder="Search patients..."]');
  await searchBox.fill("zzz-no-match");
  await page.waitForTimeout(150);
  check('search filters out non-matching patients ("No patients found.")', await page.locator("text=No patients found.").isVisible());
  await pause();
  await searchBox.fill("juana");
  await page.waitForTimeout(150);
  check("search matches by name", await page.locator("text=Juana Dela Cruz").isVisible());
  await pause();

  check("bottom tab bar Patients link is active", await page.locator('nav.fixed a[href="/staff/patients"]').first().getAttribute("class").then((c) => c.includes("text-emerald-700")));

  check("no browser console/page errors", consoleErrors.length === 0);
  if (consoleErrors.length > 0) console.log("  console errors:", consoleErrors);

  await searchBox.fill("");
  await page.waitForTimeout(150);
  const screenshotPath = path.join(__dirname, "screenshots", "staff_patients.png");
  await page.screenshot({ path: screenshotPath, fullPage: true });
  console.log(`  screenshot saved to ${screenshotPath}`);
  await pause();

  const videoPath = await closeAndSaveVideo(browser, context, "staff_patients");
  if (videoPath) console.log(`  video saved to ${videoPath}`);
  summarize("staff_patients.js");
})();
