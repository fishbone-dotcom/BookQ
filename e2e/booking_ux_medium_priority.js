// Verifies the three Medium-priority booking-wizard UX fixes:
//  1. clickable step indicators (jump back to an already-reached step)
//  2. "was: X" diff shown on the reschedule confirm screen
//  3. sessionStorage restore of doctor+date after an accidental refresh
//
// Each section signs in as a different user, so each gets its own browser
// (a fresh cookie jar) rather than trying to sign out and back in on one.
const { launch, closeAndSaveVideo, signIn } = require("./lib/browser");
const { check, summarize } = require("./lib/check");
const path = require("path");

const screenshotPath = (name) => path.join(__dirname, "screenshots", name);

async function goToStep3WithSelections(page, baseUrl) {
  await page.goto(`${baseUrl}/clinics/1/booking`);
  await page.waitForLoadState("networkidle");
  await page.locator('label:has(input[name="service_id"])').first().click();
  await page.click('button[data-action*="booking-wizard#next"]');
  await page.waitForURL(/service_id=/, { timeout: 10000 });
  await page.waitForSelector('[data-booking-wizard-target="stepPanel"][data-step="2"]:not(.hidden)');
  // pick a specific (non-"Anyone") doctor so restoring it is a meaningful check
  await page.locator('label:has(input[name="staff_id"]):not(:has(input[value=""]))').first().click();
  await page.click('button[data-action*="booking-wizard#next"]');
  // Picking a doctor now triggers a real reload (the server needs to know
  // who was picked before it can compute their own slots).
  await page.waitForURL(/staff_step=/, { timeout: 10000 });
  await page.waitForSelector('[data-booking-wizard-target="stepPanel"][data-step="3"]:not(.hidden)');
}

(async () => {
  let anyConsoleErrors = [];

  // === 1: clickable step indicators ===
  {
    const { browser, page, consoleErrors, baseUrl } = await launch();
    await signIn(page, baseUrl, "e2e.patient@bookq.test", "password123");
    await goToStep3WithSelections(page, baseUrl);

    const step1Indicator = page.locator('[data-booking-wizard-target="stepIndicator"][data-step="1"]');
    await step1Indicator.click();
    await page.waitForTimeout(100);
    check("clicking step 1's indicator from step 3 jumps back to step 1",
      await page.locator('[data-booking-wizard-target="stepPanel"][data-step="1"]').isVisible());

    const step4Indicator = page.locator('[data-booking-wizard-target="stepIndicator"][data-step="4"]');
    await step4Indicator.click();
    await page.waitForTimeout(100);
    check("clicking step 4's indicator from step 1 (not yet reached) does NOT jump ahead",
      await page.locator('[data-booking-wizard-target="stepPanel"][data-step="1"]').isVisible());

    await page.screenshot({ path: screenshotPath("booking_step_indicator_click.png") });
    anyConsoleErrors = anyConsoleErrors.concat(consoleErrors);
    await browser.close();
  }

  // === 2: "was: X" reschedule diff ===
  // patient@bookq.test already has a real appointment with Dr. Juan Dela
  // Cruz — reschedule it to a different doctor and confirm the diff shows.
  {
    const { browser, page, consoleErrors, baseUrl } = await launch();
    await signIn(page, baseUrl, "patient@bookq.test", "password123");
    await page.goto(`${baseUrl}/clinics/1/booking`);
    await page.waitForLoadState("networkidle");

    // Reschedule flow starts on whatever step the existing appointment
    // implies — jump to step 2 via the indicator to change the doctor.
    await page.locator('[data-booking-wizard-target="stepIndicator"][data-step="2"]').click();
    await page.waitForSelector('[data-booking-wizard-target="stepPanel"][data-step="2"]:not(.hidden)');

    const otherDoctorLabel = page.locator('label:has(input[name="staff_id"])').filter({ hasNotText: "Dela Cruz" }).filter({ hasNotText: "Anyone" }).first();
    await otherDoctorLabel.click();
    await page.click('button[data-action*="booking-wizard#next"]');
    // Picking a doctor now triggers a real reload (the server needs to know
    // who was picked before it can compute their own slots).
    await page.waitForURL(/staff_step=/, { timeout: 10000 });
    await page.waitForSelector('[data-booking-wizard-target="stepPanel"][data-step="3"]:not(.hidden)');

    const availableDateCell = page.locator('[data-booking-wizard-target="dateCell"]').filter({
      has: page.locator(".bg-green-500, [data-resting-class*='green']"),
    }).first();
    await availableDateCell.click();
    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(300);

    const firstSlotLabel = page.locator('label:has(input[name="starts_at"])').first();
    await firstSlotLabel.click();
    await page.click('button[data-action*="booking-wizard#next"]');
    await page.waitForSelector('[data-booking-wizard-target="stepPanel"][data-step="4"]:not(.hidden)');
    await page.waitForTimeout(100);

    const staffPreviousText = await page.locator('[data-booking-wizard-target="summaryStaffPrevious"]').textContent();
    check('confirm screen shows "was: Dr. Juan Dela Cruz" after picking a different doctor',
      staffPreviousText.includes("Dela Cruz"));
    check("date previous diff is visible (date changed too)",
      await page.locator('[data-booking-wizard-target="summaryDatePrevious"]').isVisible());

    await page.screenshot({ path: screenshotPath("booking_reschedule_diff.png") });
    anyConsoleErrors = anyConsoleErrors.concat(consoleErrors);
    await browser.close();
  }

  // === 3: sessionStorage restore after refresh ===
  {
    const { browser, page, consoleErrors, baseUrl } = await launch();
    await signIn(page, baseUrl, "e2e.patient@bookq.test", "password123");
    await goToStep3WithSelections(page, baseUrl);

    const chosenStaffName = await page.locator('input[name="staff_id"]:checked').evaluate((el) => el.dataset.name);
    const availableCell = page.locator('[data-booking-wizard-target="dateCell"]').filter({
      has: page.locator(".bg-green-500, [data-resting-class*='green']"),
    }).first();
    const chosenDate = await availableCell.getAttribute("data-date");
    await availableCell.click();
    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(300);

    await page.reload();
    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(300);

    check("after refresh, wizard is back on step 3 (not step 1)",
      await page.locator('[data-booking-wizard-target="stepPanel"][data-step="3"]').isVisible());

    const restoredStaffChecked = await page.locator('input[name="staff_id"]:checked').evaluate((el) => el.dataset.name).catch(() => null);
    check(`doctor selection (${chosenStaffName}) survived the refresh`, restoredStaffChecked === chosenStaffName);

    const restoredDate = await page.locator('[data-booking-wizard-target="hiddenDate"]').inputValue();
    check(`date selection (${chosenDate}) survived the refresh`, restoredDate === chosenDate);

    await page.screenshot({ path: screenshotPath("booking_refresh_restored.png") });
    anyConsoleErrors = anyConsoleErrors.concat(consoleErrors);
    await browser.close();
  }

  check("no console errors across all sections", anyConsoleErrors.length === 0);
  if (anyConsoleErrors.length > 0) console.log("  console errors:", anyConsoleErrors);

  summarize("booking_ux_medium_priority");
})();
