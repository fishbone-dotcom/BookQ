// Playwright smoke check for docs/admin_portal/04_add_doctor.md.
// Usage: node e2e/staff_add_doctor.js  (see e2e/README.md for setup)
//
// Creates a throwaway doctor account with a timestamped email so repeat runs
// never collide with the duplicate-email validation, then cleans it up via
// `bin/rails runner` at the end so it doesn't accumulate in the dev DB. That
// cleanup runs in a `finally` block — a crash partway through a past version
// of this script (before it used waitForURL) once left an orphaned test
// doctor behind because cleanup was the last line, not guaranteed to run.
//
// Uses page.waitForURL() (polls until the URL matches, or times out) rather
// than a fixed waitForTimeout after each navigation — this app's slowest
// request here (creating a User bcrypt-hashes a password) varies enough in
// duration that a fixed sleep was flaky even at 700ms.
const { execSync } = require("child_process");
const { launch, closeAndSaveVideo, signIn } = require("./lib/browser");
const { check, summarize } = require("./lib/check");
const path = require("path");

const testEmail = `e2e-doctor-${Date.now()}@example.com`;

function cleanup() {
  try {
    execSync(
      `cd .. && bin/rails runner 'u = User.find_by(email: "${testEmail}"); u&.clinic_staffs&.destroy_all; u&.destroy'`,
      { stdio: "pipe" }
    );
    console.log("  cleanup: removed the throwaway doctor account");
  } catch (e) {
    console.log("  cleanup warning: could not remove throwaway doctor account —", e.message);
  }
}

(async () => {
  const { browser, context, page, consoleErrors, baseUrl, recordingVideo } = await launch();
  const pause = () => page.waitForTimeout(recordingVideo ? 700 : 0);

  try {
    // A plain staff member (not owner) should not be able to reach the form.
    await signIn(page, baseUrl, "doctor@bookq.test", "password123");
    await pause();
    await page.goto(`${baseUrl}/staff/doctors/new`);
    await page.waitForURL(`${baseUrl}/staff/doctors`, { timeout: 10000 });
    await pause();
    check("plain staff is redirected away from Add Doctor", page.url() === `${baseUrl}/staff/doctors`);
    await page.locator('button[data-action="staff-nav#open"]').first().click();
    await page.waitForTimeout(300);
    await page.click('button:has-text("Log out")');
    await page.waitForURL(`${baseUrl}/`, { timeout: 10000 });
    await pause();

    // The clinic owner can.
    await signIn(page, baseUrl, "owner@bookq.test", "password123");
    await pause();
    await page.locator('button[data-action="staff-nav#open"]').first().click();
    await page.waitForTimeout(300);
    await page.click('aside a:has-text("Doctors")');
    await page.waitForURL(`${baseUrl}/staff/doctors`, { timeout: 10000 });
    await pause();

    await page.click('a[href="/staff/doctors/new"]');
    await page.waitForURL(`${baseUrl}/staff/doctors/new`, { timeout: 10000 });
    await pause();
    check("Add Doctor page loads for the owner", page.url() === `${baseUrl}/staff/doctors/new`);
    check("no <select> tags (radio-card convention)", await page.locator("select").count() === 0);

    await page.fill('input[name="name"]', "Dr. E2E Test");
    await page.fill('input[name="specialization"]', "Dermatologist");
    await page.fill('input[name="email"]', testEmail);
    await page.fill('input[name="phone"]', "0917-555-0100");
    await page.click('label:has-text("On Leave")');
    await pause();

    await page.click('input[type="submit"][value="Save Doctor"]');
    await page.waitForURL(`${baseUrl}/staff/doctors`, { timeout: 10000 });
    await page.locator("text=Dr. E2E Test").first().waitFor({ timeout: 10000 });
    await pause();

    check("saving redirects to the Doctors list", page.url() === `${baseUrl}/staff/doctors`);
    const bodyText = await page.locator("body").innerText();
    check("new doctor appears in the list", bodyText.includes("Dr. E2E Test") && bodyText.includes("Dermatologist"));
    check("new doctor shows as On Leave", bodyText.includes("On Leave"));

    check("no browser console/page errors", consoleErrors.length === 0);
    if (consoleErrors.length > 0) console.log("  console errors:", consoleErrors);

    const screenshotPath = path.join(__dirname, "screenshots", "staff_add_doctor.png");
    await page.screenshot({ path: screenshotPath, fullPage: true });
    console.log(`  screenshot saved to ${screenshotPath}`);
    await pause();

    const videoPath = await closeAndSaveVideo(browser, context, "staff_add_doctor");
    if (videoPath) console.log(`  video saved to ${videoPath}`);
  } finally {
    await browser.close().catch(() => {});
    cleanup();
  }

  summarize("staff_add_doctor.js");
})();
