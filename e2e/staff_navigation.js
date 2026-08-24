// Playwright smoke check for docs/admin_portal/02_navigation.md.
// Usage: node e2e/staff_navigation.js  (see e2e/README.md for setup)
const { launch, closeAndSaveVideo, signIn } = require("./lib/browser");
const { check, summarize } = require("./lib/check");
const path = require("path");

(async () => {
  const { browser, context, page, consoleErrors, baseUrl, recordingVideo } = await launch();
  const pause = () => page.waitForTimeout(recordingVideo ? 700 : 0);

  await signIn(page, baseUrl, "owner@bookq.test", "password123");
  await pause();

  const panel = page.locator('[data-staff-nav-target="panel"]');
  const overlay = page.locator('[data-staff-nav-target="overlay"]');

  check("drawer starts closed", !(await panel.isVisible()) || (await panel.boundingBox())?.x < 0);
  await pause();

  // Opening via the header hamburger button.
  await page.locator('button[data-action="staff-nav#open"]').first().click();
  await page.waitForTimeout(300);
  let panelBox = await panel.boundingBox();
  check("hamburger button opens the drawer", panelBox && panelBox.x >= -1);
  check("overlay is visible while the drawer is open", await overlay.isVisible());
  await pause();

  check("Dashboard is a real, highlighted link in the drawer", await page.locator('aside a:has-text("Dashboard")').count() > 0);
  check("Appointments is a real link in the drawer", await page.locator('aside a:has-text("Appointments")').count() > 0);

  const placeholderLabels = [ "Doctors", "Patients", "Patient Records", "Billing & Payments", "Inventory", "Reports", "Notifications", "Settings" ];
  let allPlaceholders = true;
  for (const label of placeholderLabels) {
    const isLink = await page.locator(`aside a:has-text("${label}")`).count() > 0;
    if (isLink) allPlaceholders = false;
  }
  check("unimplemented sections are not rendered as working links", allPlaceholders);
  check(`all ${placeholderLabels.length} placeholder sections show a "Soon" badge`, (await page.locator("aside").getByText("Soon", { exact: true }).count()) === placeholderLabels.length);

  check("footer shows the staffer's name", (await page.locator("aside").innerText()).includes("Dr. Maria Santos"));
  check("footer shows the staffer's clinic role", (await page.locator("aside").innerText()).includes("Clinic Owner"));

  // Closing via the X button.
  await page.locator('button[data-action="staff-nav#close"]').click();
  await page.waitForTimeout(300);
  panelBox = await panel.boundingBox();
  check("close button closes the drawer", !panelBox || panelBox.x < 0);
  await pause();

  // Opening via the bottom "More" tab, closing via overlay click.
  await page.locator('button:has-text("More")').click();
  await page.waitForTimeout(300);
  check('bottom "More" tab also opens the drawer', (await panel.boundingBox())?.x >= -1);
  await pause();
  await overlay.click({ position: { x: 400, y: 100 } }); // right of the ~288px-wide drawer panel
  await page.waitForTimeout(300);
  panelBox = await panel.boundingBox();
  check("clicking the overlay closes the drawer", !panelBox || panelBox.x < 0);
  await pause();

  check("no browser console/page errors", consoleErrors.length === 0);
  if (consoleErrors.length > 0) console.log("  console errors:", consoleErrors);

  const screenshotPath = path.join(__dirname, "screenshots", "staff_navigation_open.png");
  await page.locator('button[data-action="staff-nav#open"]').first().click();
  await page.waitForTimeout(300);
  await page.screenshot({ path: screenshotPath, fullPage: true });
  console.log(`  screenshot saved to ${screenshotPath}`);
  await pause();

  const videoPath = await closeAndSaveVideo(browser, context, "staff_navigation");
  if (videoPath) console.log(`  video saved to ${videoPath}`);
  summarize("staff_navigation.js");
})();
