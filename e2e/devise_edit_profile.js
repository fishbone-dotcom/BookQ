// Playwright smoke check for the Profile / Change Password pages
// (app/views/users/registrations/edit.html.erb + edit_password.html.erb).
// Originally the raw unstyled Devise scaffold (fixed to match the app's
// Tailwind conventions), then split into two separate pages per user
// feedback: "user detail" (name/email) shouldn't be mixed with password
// fields on the same form — those are different concerns/sections.
// Usage: node e2e/devise_edit_profile.js
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
  await page.click('aside a:has-text("Settings")');
  await page.waitForURL(`${baseUrl}/staff/settings`, { timeout: 10000 });
  await pause();

  await page.click('a[href="/users/edit"]');
  await page.waitForURL(`${baseUrl}/users/edit`, { timeout: 10000 });
  await pause();

  check("Profile page loads", page.url() === `${baseUrl}/users/edit`);
  check("styled with the app's card/form conventions (rounded input classes present)", await page.locator("input.rounded-lg").count() > 0);
  check("has a Name field", await page.locator('input[name="user[name]"]').count() === 1);
  check("has an Email field", await page.locator('input[name="user[email]"]').count() === 1);
  check("does NOT have password fields — those live on their own page", await page.locator('input[name="user[password]"]').count() === 0);
  check("has a styled Save Changes button", await page.locator('input[type="submit"][value="Save Changes"]').count() === 1);
  check("has a Back link", await page.locator("text=← Back").count() === 1);

  await page.click("text=← Back");
  await page.waitForURL(`${baseUrl}/staff/settings`, { timeout: 10000 });
  check("Back link returns to the actual previous page (Settings), not a fixed home page", page.url() === `${baseUrl}/staff/settings`);
  await pause();

  // Change Password lives on its own page, reached from Settings directly.
  await page.click('a[href="/users/change_password"]');
  await page.waitForURL(`${baseUrl}/users/change_password`, { timeout: 10000 });
  await pause();

  check("Change Password page loads", page.url() === `${baseUrl}/users/change_password`);
  check("has New Password + Confirm fields", await page.locator('input[name="user[password]"]').count() === 1
    && await page.locator('input[name="user[password_confirmation]"]').count() === 1);
  check("does NOT have Name/Email fields — those live on the Profile page", await page.locator('input[name="user[name]"]').count() === 0
    && await page.locator('input[name="user[email]"]').count() === 0);
  check("still requires current password to confirm the change", await page.locator('input[name="user[current_password]"]').count() === 1);

  await page.click("text=← Back");
  await page.waitForURL(`${baseUrl}/users/edit`, { timeout: 10000 });
  check("Change Password's Back link returns to Profile", page.url() === `${baseUrl}/users/edit`);
  await pause();
  check("Cancel my account is styled as a danger button, not a plain link", await page.locator('button:has-text("Cancel my account")').count() === 1);

  check("no browser console/page errors", consoleErrors.length === 0);
  if (consoleErrors.length > 0) console.log("  console errors:", consoleErrors);

  const screenshotPath = path.join(__dirname, "screenshots", "devise_edit_profile.png");
  await page.screenshot({ path: screenshotPath, fullPage: true });
  console.log(`  screenshot saved to ${screenshotPath}`);
  await pause();

  const videoPath = await closeAndSaveVideo(browser, context, "devise_edit_profile");
  if (videoPath) console.log(`  video saved to ${videoPath}`);
  summarize("devise_edit_profile.js");
})();
