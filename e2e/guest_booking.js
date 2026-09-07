// End-to-end walk of the guest booking flow: landing page "Get Started" →
// Find a clinic → booking wizard (service/doctor/schedule/contact info) →
// confirm → guest management/confirmation page. Filters the clinic search
// down to the known seeded "Sunrise Family Clinic" so this doesn't depend
// on whatever leftover fixture clinics other scripts happen to have left
// around. Uses a dedicated fixture email and cancels the booking it creates
// at the end so the script is safely re-runnable.
const { launch } = require("./lib/browser");
const { check, summarize } = require("./lib/check");
const path = require("path");

const GUEST_EMAIL = "e2e.guest@example.com";

async function waitForStep(page, step) {
  await page.waitForFunction(
    (n) => document.querySelector("[data-controller='booking-wizard']")?.dataset.bookingWizardStepValue === String(n),
    step,
    { timeout: 10000 }
  );
}

(async () => {
  const { browser, page, baseUrl, consoleErrors } = await launch();

  try {
    await page.goto(`${baseUrl}/`);
    await page.waitForLoadState("networkidle");
    check("landing page loads signed out", page.url() === `${baseUrl}/`);

    // Hero "Get Started" should anchor to the Find a clinic section, not require login.
    await page.click('a:has-text("Get Started")');
    await page.locator("#find-clinic").waitFor();
    check("Get Started reveals the Find a clinic section", await page.locator("#find-clinic").isVisible());

    await page.fill("#find-clinic input[type=text]", "Sunrise Family Clinic");
    await page.click('#find-clinic a:has-text("Sunrise Family Clinic")');
    await page.waitForURL(/\/clinics\/\d+\/booking/, { timeout: 10000 });
    check("clicking a clinic opens the booking wizard without requiring sign-in", true);

    // Step 1: Service (first one is preselected by the server, so just
    // advance) — "Next" here does a real GET reload (server needs to know
    // the service before computing doctor/slot options), not a client-side
    // step change.
    await waitForStep(page, 1);
    await page.click('button:has-text("Next")');
    await waitForStep(page, 2);

    // Step 2: Doctor — "Anyone" is preselected. Also a real GET reload.
    await page.click('button:has-text("Next")');
    await waitForStep(page, 3);

    // Step 3: Schedule — pick the first available date, then the first open slot.
    const availableDate = page.locator('[data-booking-wizard-target="dateCell"]').filter({ has: page.locator(".avail-dot.bg-green-500") }).first();
    await availableDate.click();
    await page.waitForLoadState("networkidle");
    const firstSlot = page.locator('input[name="starts_at"]').first();
    await firstSlot.waitFor({ timeout: 10000 });
    await firstSlot.click({ force: true });
    await page.click('button:has-text("Next")');
    await waitForStep(page, 4);

    // Step 4: Confirm — guest contact info fields should be present (signed out).
    await page.locator("#guest_name").waitFor();
    check("guest contact-info fields render on the confirm step", await page.locator("#guest_name").isVisible());

    await page.fill("#guest_name", "E2E Guest");
    await page.fill("#guest_email", GUEST_EMAIL);
    await page.fill("#guest_phone", "09171234567");

    // The submit control is a plain `f.submit` (<input type="submit">), not a <button>.
    await page.click('input[type="submit"][value="Book"]');
    await page.waitForURL(/\/guest_appointments\//, { timeout: 10000 });

    const body = await page.locator("body").textContent();
    check("redirected to the guest confirmation page", /guest_appointments/.test(page.url()));
    check("shows the 'Appointment confirmed!' flash", body.includes("Appointment confirmed"));
    check("shows the account-creation offer", body.includes("Want to manage your appointments more easily"));
    check("offers both Create account and Continue without an account", body.includes("Create account") && body.includes("Continue without an account"));

    await page.screenshot({ path: path.join(__dirname, "screenshots", "guest_booking.png"), fullPage: true });

    // Clean up: cancel the booking via the same page's Cancel button. This
    // app overrides Turbo's confirm with a custom <dialog>, not the native
    // browser confirm() — click its "OK" choice, not page.on("dialog").
    await page.click('button:has-text("Cancel booking")');
    await page.locator('dialog [data-choice="ok"]').waitFor({ timeout: 5000 });
    await page.locator('dialog [data-choice="ok"]').click();
    await page.waitForFunction(() => document.body.textContent.includes("This booking is cancelled"), null, { timeout: 10000 });
    const afterCancel = await page.locator("body").textContent();
    check("booking shows as cancelled after clicking Cancel", afterCancel.includes("cancelled"));

    check("no console errors", consoleErrors.length === 0);
    if (consoleErrors.length > 0) console.log("  console errors:", consoleErrors);
  } finally {
    await browser.close();
  }

  summarize("guest_booking");
})();
