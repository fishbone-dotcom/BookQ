// Playwright smoke check for docs/admin_portal/16_settings.md.
// Usage: node e2e/staff_settings.js  (see e2e/README.md for setup)
//
// Creates a throwaway owner + clinic + colleague staffer via `bin/rails
// runner` so role-change/remove actions don't touch the shared seed data,
// cleaned up in a `finally` block (see e2e/staff_add_doctor.js for why).
const { execSync } = require("child_process");
const { launch, closeAndSaveVideo, signIn } = require("./lib/browser");
const { check, summarize } = require("./lib/check");
const path = require("path");

const stamp = Date.now();
const ownerEmail = `e2e-settings-owner-${stamp}@example.com`;
const staffEmail = `e2e-settings-staff-${stamp}@example.com`;

function setup() {
  const setupScript = `
    owner = User.create!(email: "${ownerEmail}", password: "password123", password_confirmation: "password123", role: :staff, name: "E2E Settings Owner")
    clinic = Clinic.create!(name: "E2E Settings Clinic", address: "1 Test St.", phone: "0917-000-0000", owner: owner)
    ClinicStaff.create!(clinic: clinic, user: owner, role: :owner)
    colleague = User.create!(email: "${staffEmail}", password: "password123", password_confirmation: "password123", role: :staff, name: "E2E Settings Colleague")
    ClinicStaff.create!(clinic: clinic, user: colleague, role: :staff)
    puts "OK"
  `;
  execSync(`cd .. && bin/rails runner '${setupScript}'`, { encoding: "utf8" });
}

function cleanup() {
  try {
    execSync(
      `cd .. && bin/rails runner 'Clinic.find_by(name: "E2E Settings Clinic")&.destroy; ` +
        `User.where(email: ["${ownerEmail}", "${staffEmail}"]).destroy_all'`,
      { stdio: "pipe" }
    );
    console.log("  cleanup: removed the throwaway owner/clinic/staffer");
  } catch (e) {
    console.log("  cleanup warning: could not remove throwaway test data —", e.message);
  }
}

(async () => {
  setup();
  const { browser, context, page, consoleErrors, baseUrl, recordingVideo } = await launch();
  const pause = () => page.waitForTimeout(recordingVideo ? 700 : 0);

  try {
    await signIn(page, baseUrl, ownerEmail, "password123");
    await pause();

    await page.locator('button[data-action="staff-nav#open"]').first().click();
    await page.waitForTimeout(300);
    await page.click('aside a:has-text("Settings")');
    await page.waitForURL(`${baseUrl}/staff/settings`, { timeout: 10000 });
    await pause();

    check("Settings landing page loads for the owner", page.url() === `${baseUrl}/staff/settings`);
    check("owner sees real links, not 'Owner only'", !(await page.locator("body").innerText()).includes("Owner only"));

    // Clinic Information.
    await page.click('a[href="/staff/settings/clinic"]');
    await page.waitForURL(`${baseUrl}/staff/settings/clinic`, { timeout: 10000 });
    await pause();
    check("Clinic Information pre-fills the clinic name", await page.locator('input[name="clinic[name]"]').inputValue() === "E2E Settings Clinic");
    await page.fill('input[name="clinic[address]"]', "2 Updated Ave.");
    await page.click('input[type="submit"][value="Save Changes"]');
    await page.waitForURL(`${baseUrl}/staff/settings`, { timeout: 10000 });
    await pause();
    check("saving clinic info redirects back with a notice", (await page.locator("body").innerText()).includes("Clinic information updated"));

    // Working Hours.
    await page.click('a[href="/staff/settings/hours"]');
    await page.waitForURL(`${baseUrl}/staff/settings/hours`, { timeout: 10000 });
    await pause();
    check("Working Hours shows all 7 days", (await page.locator("body").innerText()).includes("Sunday") && (await page.locator("body").innerText()).includes("Saturday"));
    check("no <select> tags (radio-card/checkbox convention)", await page.locator("select").count() === 0);
    await Promise.all([
      page.waitForResponse((res) => res.url() === `${baseUrl}/staff/settings/hours` && res.request().method() === "GET"),
      page.click('input[type="submit"][value="Save Working Hours"]'),
    ]);
    await pause();
    check("saving working hours shows a notice", (await page.locator("body").innerText()).includes("Working hours updated"));

    // Users & Roles.
    await page.goto(`${baseUrl}/staff/clinic_staffs`);
    await pause();
    check("Users & Roles lists the colleague", (await page.locator("body").innerText()).includes("E2E Settings Colleague"));

    await Promise.all([
      page.waitForResponse((res) => res.url() === `${baseUrl}/staff/clinic_staffs` && res.request().method() === "GET"),
      page.click('label:has-text("Owner")'),
    ]);
    await pause();
    check("promoting the colleague shows a notice", (await page.locator("body").innerText()).includes("role updated"));

    check("no browser console/page errors", consoleErrors.length === 0);
    if (consoleErrors.length > 0) console.log("  console errors:", consoleErrors);

    const screenshotPath = path.join(__dirname, "screenshots", "staff_settings.png");
    await page.screenshot({ path: screenshotPath, fullPage: true });
    console.log(`  screenshot saved to ${screenshotPath}`);
    await pause();

    const videoPath = await closeAndSaveVideo(browser, context, "staff_settings");
    if (videoPath) console.log(`  video saved to ${videoPath}`);
  } finally {
    await browser.close().catch(() => {});
    cleanup();
  }

  summarize("staff_settings.js");
})();
