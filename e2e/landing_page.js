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

  // Nav
  check("nav has a 'Log in' link", body.includes("Log in"));

  // Hero
  check("hero headline is present", body.includes("A Smarter Way to") && body.includes("Book Clinic Appointments"));
  check("hero has a 'Get Started' button", body.includes("Get Started"));
  check("hero has a 'continue with Google' link", body.includes("continue with Google"));

  // Features
  check("features section heading is present", body.includes("Everything a clinic needs to manage bookings"));
  check("mentions real-time availability", body.includes("Real-time availability"));
  check("mentions no double-booking", body.includes("No double-booking"));

  // How it works
  check("how-it-works heading is present", body.includes("Book in three simple steps"));
  check("step 1 'Find a clinic' is present", body.includes("Find a clinic"));
  check("step 3 'Get confirmed' is present", body.includes("Get confirmed"));

  // Illustrated tagline banner
  check("tagline banner is present", body.includes("Better care. Less hassle."));

  // The Google button's form action should point at the omniauth authorize path.
  const googleForms = await page.locator('form[action*="/users/auth/google_oauth2"]').count();
  check("a form posts to /users/auth/google_oauth2", googleForms >= 1);

  await page.screenshot({ path: path.join(__dirname, "screenshots", "landing_page.png"), fullPage: true });

  check("no console errors", consoleErrors.length === 0);
  if (consoleErrors.length > 0) console.log("  console errors:", consoleErrors);

  await browser.close();
  summarize("landing_page");
})();
