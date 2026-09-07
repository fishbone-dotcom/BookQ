// Verifies the logged-out marketing landing page (Hero / Features / How it
// works / Closing CTA) renders correctly and the "Continue with Google"
// button points at the right OmniAuth path. Doesn't complete a real Google
// login — that isn't automatable and shouldn't be attempted with real
// credentials in a script.
const { launch } = require("./lib/browser");
const { check, summarize } = require("./lib/check");
const path = require("path");

(async () => {
  const { browser, page, baseUrl, consoleErrors } = await launch();

  await page.goto(`${baseUrl}/`);
  await page.waitForLoadState("networkidle");

  const body = await page.locator("body").textContent();

  // Hero
  check("hero headline is present", body.includes("Clinic booking, without the Messenger back-and-forth"));
  check("hero has a 'Continue with Google' button", body.includes("Continue with Google"));
  check("hero has a 'Sign up with email' link", body.includes("Sign up with email"));

  // Features
  check("features section heading is present", body.includes("Everything a clinic needs to manage bookings"));
  check("mentions real-time availability", body.includes("Real-time availability"));
  check("mentions no double-booking", body.includes("No double-booking"));

  // How it works
  check("how-it-works heading is present", body.includes("How it works"));
  check("step 1 'Find a clinic' is present", body.includes("Find a clinic"));
  check("step 3 'Get confirmed' is present", body.includes("Get confirmed"));

  // Closing CTA
  check("closing CTA heading is present", body.includes("Ready to book your first appointment?"));

  // The Google button's form action should point at the omniauth authorize path.
  const googleForms = await page.locator('form[action*="/users/auth/google_oauth2"]').count();
  check("at least one form posts to /users/auth/google_oauth2", googleForms >= 2); // hero + closing CTA

  await page.screenshot({ path: path.join(__dirname, "screenshots", "landing_page.png"), fullPage: true });

  check("no console errors", consoleErrors.length === 0);
  if (consoleErrors.length > 0) console.log("  console errors:", consoleErrors);

  await browser.close();
  summarize("landing_page");
})();
