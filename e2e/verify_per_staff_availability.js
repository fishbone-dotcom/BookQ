// Manual/e2e verification for the per-doctor scheduling plan (Phase A + B):
// (b) a doctor's own narrower hours override the clinic default,
// (c) "Anyone" auto-assigns the one doctor actually free at that time,
// (a) marking that doctor unavailable cancels the booking and emails the patient.
//
// Uses a dedicated "E2E Verify Clinic" fixture (see the `bin/rails runner`
// snippet run alongside this script) so it never touches shared demo data.
const { launch, signIn } = require("./lib/browser");
const { check, summarize } = require("./lib/check");
const path = require("path");

function nextMonday() {
  const d = new Date();
  d.setDate(d.getDate() + ((8 - d.getDay()) % 7 || 7));
  return d;
}

(async () => {
  const monday = nextMonday();
  const mondayLabel = monday.toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" }).replace(/(\w+) (\w+) 0*(\d+)/, "$1, $2 $3");

  // === (b): a doctor's own hours override the clinic default ===
  {
    const { browser, page, baseUrl } = await launch();
    await signIn(page, baseUrl, "e2e-verify-patient@example.com", "password123");
    await page.goto(`${baseUrl}/clinics/21/booking`);
    await page.waitForLoadState("networkidle");

    await page.locator('label:has(input[name="service_id"])').first().click();
    await page.click('button[data-action*="booking-wizard#next"]');
    await page.waitForURL(/service_id=/, { timeout: 10000 });
    await page.waitForSelector('[data-booking-wizard-target="stepPanel"][data-step="2"]:not(.hidden)');

    await page.locator('label:has-text("Dr. Alpha")').click();
    await page.click('button[data-action*="booking-wizard#next"]');
    await page.waitForURL(/staff_step=/, { timeout: 10000 });
    await page.waitForSelector('[data-booking-wizard-target="stepPanel"][data-step="3"]:not(.hidden)');

    const mondayCell = page.locator(`[data-booking-wizard-target="dateCell"][data-label="${mondayLabel}"]`);
    await mondayCell.click();
    await page.waitForSelector('turbo-frame#slots:not([busy])');
    await page.waitForFunction(() => document.querySelectorAll('label:has(input[name="starts_at"])').length > 0
      || document.querySelector("turbo-frame#slots").textContent.includes("No available"));

    const slotLabels = (await page.locator('label:has(input[name="starts_at"])').allTextContents()).map((l) => l.trim());
    check(`Dr. Alpha's slots stop at 10:30 AM (his 9-11 override), not the clinic's 9-5 default (saw: ${slotLabels.join(", ")})`,
      slotLabels.every((l) => !l.includes("11:") && !l.includes("PM")));
    check("Dr. Alpha has slots at all within his override window", slotLabels.includes("9:00 AM") && slotLabels.includes("10:30 AM"));

    await page.screenshot({ path: path.join(__dirname, "screenshots", "verify_doctor_override_hours.png") });
    await browser.close();
  }

  // === (c): "Anyone" auto-assigns the one doctor actually free ===
  {
    const { browser, page, baseUrl } = await launch();
    await signIn(page, baseUrl, "e2e-verify-patient@example.com", "password123");
    await page.goto(`${baseUrl}/clinics/21/booking`);
    await page.waitForLoadState("networkidle");

    await page.locator('label:has(input[name="service_id"])').first().click();
    await page.click('button[data-action*="booking-wizard#next"]');
    await page.waitForURL(/service_id=/, { timeout: 10000 });
    await page.waitForSelector('[data-booking-wizard-target="stepPanel"][data-step="2"]:not(.hidden)');

    await page.locator('label:has-text("Anyone")').click();
    await page.click('button[data-action*="booking-wizard#next"]');
    await page.waitForURL(/staff_step=/, { timeout: 10000 });
    await page.waitForSelector('[data-booking-wizard-target="stepPanel"][data-step="3"]:not(.hidden)');

    const mondayCell = page.locator(`[data-booking-wizard-target="dateCell"][data-label="${mondayLabel}"]`);
    await mondayCell.click();
    await page.waitForSelector('turbo-frame#slots:not([busy])');
    await page.waitForFunction(() => document.querySelectorAll('label:has(input[name="starts_at"])').length > 0
      || document.querySelector("turbo-frame#slots").textContent.includes("No available"));

    // 2:00 PM is outside Dr. Alpha's 9-11 override but inside Dr. Beta's
    // clinic-default fallback hours — only Beta should be bookable then.
    await page.locator('input[name="starts_at"][data-label="2:00 PM"]').click({ force: true });
    await page.click('button[data-action*="booking-wizard#next"]');
    await page.waitForSelector('[data-booking-wizard-target="stepPanel"][data-step="4"]:not(.hidden)');
    await page.click('input[data-booking-wizard-target="submitButton"]');
    await page.waitForURL(`${baseUrl}/`);

    check("booking succeeded and landed back on the home page", page.url() === `${baseUrl}/`);
    const upcomingCard = await page.locator("body").textContent();
    check("the auto-assigned doctor shown on the home page is Dr. Beta (the only one free at 2 PM)",
      upcomingCard.includes("Dr. Beta"));

    await page.screenshot({ path: path.join(__dirname, "screenshots", "verify_anyone_auto_assigned.png") });
    await browser.close();
  }

  // === (a): marking the assigned doctor unavailable cancels + notifies ===
  {
    const { browser, page, baseUrl } = await launch();
    await signIn(page, baseUrl, "e2e-verify-owner@example.com", "password123");
    await page.goto(`${baseUrl}/staff/doctors`);
    await page.waitForLoadState("networkidle");

    await page.click('div.rounded-xl:has-text("Dr. Beta") a[href*="/unavailability/new"]');
    await page.waitForURL(/unavailability\/new/, { timeout: 10000 });

    await page.fill("#from_date", monday.toISOString().slice(0, 10));
    await page.fill("#to_date", monday.toISOString().slice(0, 10));
    await page.click('input[type="submit"]');
    // This app's data-turbo-confirm uses a custom <dialog> (see
    // app/javascript/application.js), not the native confirm() Playwright's
    // page.on("dialog") listens for.
    await page.click('dialog button[data-choice="ok"]');
    await page.waitForURL(`${baseUrl}/staff/doctors`, { timeout: 10000 });

    const flash = await page.locator("body").textContent();
    check("staff sees a confirmation that an appointment was cancelled and a patient notified",
      /Cancelled 1 appointment/.test(flash));

    await page.screenshot({ path: path.join(__dirname, "screenshots", "verify_mark_unavailable.png") });
    await browser.close();
  }

  // Confirm the patient's appointment is really gone.
  {
    const { browser, page, baseUrl } = await launch();
    await signIn(page, baseUrl, "e2e-verify-patient@example.com", "password123");

    const homeBody = await page.locator("body").textContent();
    check("patient's upcoming-appointment card is now empty after the cancellation",
      homeBody.includes("You don't have an upcoming appointment yet"));

    await browser.close();
  }

  summarize("verify_per_staff_availability");
})();
