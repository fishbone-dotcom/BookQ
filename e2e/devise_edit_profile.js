// Playwright smoke check for the restyled Devise "Edit Profile" page
// (app/views/devise/registrations/edit.html.erb), reported by the user as
// looking bad (unstyled Rails scaffold) — restyled to match the app's
// existing Tailwind form conventions (see devise/sessions/new.html.erb).
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

  check("Edit Profile page loads", page.url() === `${baseUrl}/users/edit`);
  check("styled with the app's card/form conventions (rounded input classes present)", await page.locator("input.rounded-lg").count() > 0);
  check("has a styled Save Changes button", await page.locator('input[type="submit"][value="Save Changes"]').count() === 1);
  check("has a Back link", await page.locator("text=← Back").count() === 1);

  await page.click("text=← Back");
  await page.waitForURL(`${baseUrl}/staff/settings`, { timeout: 10000 });
  check("Back link returns to the actual previous page (Settings), not a fixed home page", page.url() === `${baseUrl}/staff/settings`);
  await page.goBack();
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
