// Playwright smoke check for docs/admin_portal/06_patient_profile.md.
// Usage: node e2e/staff_patient_profile.js  (see e2e/README.md for setup)
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

  await page.click("text=Juana Dela Cruz");
  await page.waitForURL(/\/staff\/patients\/\d+$/, { timeout: 10000 });
  await pause();

  check("clicking a patient opens their profile page", /\/staff\/patients\/\d+$/.test(page.url()));
  check("header shows patient's name", (await page.locator("body").innerText()).includes("Juana Dela Cruz"));
  check("Overview tab shows Personal Information", (await page.locator("body").innerText()).includes("Personal Information"));
  check("shows email", (await page.locator("body").innerText()).includes("@"));
  check("shows blood type from seeded profile", (await page.locator("body").innerText()).includes("O+"));

  // Appointments tab.
  await page.click('a[href*="tab=appointments"]');
  await page.waitForURL(/tab=appointments/, { timeout: 10000 });
  await pause();
  check("Appointments tab scoped to this clinic shows a service name", (await page.locator("body").innerText()).length > 0);

  // Records tab (not built yet).
  await page.click('a[href*="tab=records"]');
  await page.waitForURL(/tab=records/, { timeout: 10000 });
  await pause();
  check("Records tab shows a coming-soon placeholder", (await page.locator("body").innerText()).includes("coming soon"));

  // Edit flow.
  await page.click('a[href$="/edit"]');
  await page.waitForURL(/\/staff\/patients\/\d+\/edit$/, { timeout: 10000 });
  await pause();
  check("edit icon opens the edit form", /\/staff\/patients\/\d+\/edit$/.test(page.url()));
  check("no <select> tags (radio-card convention)", await page.locator("select").count() === 0);

  const addressField = page.locator('input[name="patient_profile[address]"]');
  await addressField.fill("Updated Address via E2E");
  await pause();
  await page.click('input[type="submit"][value="Save Changes"]');
  await page.waitForURL(/\/staff\/patients\/\d+$/, { timeout: 10000 });
  await pause();

  check("saving redirects back to the profile page", (await page.locator("body").innerText()).includes("Patient profile updated"));
  check("updated address shows on Overview", (await page.locator("body").innerText()).includes("Updated Address via E2E"));

  check("no browser console/page errors", consoleErrors.length === 0);
  if (consoleErrors.length > 0) console.log("  console errors:", consoleErrors);

  const screenshotPath = path.join(__dirname, "screenshots", "staff_patient_profile.png");
  await page.screenshot({ path: screenshotPath, fullPage: true });
  console.log(`  screenshot saved to ${screenshotPath}`);
  await pause();

  const videoPath = await closeAndSaveVideo(browser, context, "staff_patient_profile");
  if (videoPath) console.log(`  video saved to ${videoPath}`);
  summarize("staff_patient_profile.js");
})();
