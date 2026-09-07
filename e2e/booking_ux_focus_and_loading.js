const { launch, closeAndSaveVideo, signIn } = require("./lib/browser");
const { check, summarize } = require("./lib/check");
const path = require("path");

const screenshotPath = (name) => path.join(__dirname, "screenshots", name);

(async () => {
  const { browser, context, page, consoleErrors, baseUrl, recordingVideo } = await launch();

  try {
    // Dedicated fixture patient with no existing booking — the seeded
    // patient@bookq.test already has an active appointment with clinic 1,
    // which sends the wizard straight to step 4 (reschedule) instead of the
    // clean step-1 start this check needs.
    await signIn(page, baseUrl, "e2e.patient@bookq.test", "password123");
    await page.goto(`${baseUrl}/clinics/1/booking`);
    await page.waitForLoadState("networkidle");

    // --- Step 1: service card focus-visible ring ---
    const firstServiceLabel = page.locator('label:has(input[name="service_id"])').first();
    await firstServiceLabel.locator('input[name="service_id"]').focus();
    await page.screenshot({ path: screenshotPath("booking_step1_focus.png") });

    const step1RingBox = await firstServiceLabel.evaluate((el) => {
      const style = getComputedStyle(el);
      return { boxShadow: style.boxShadow, outline: style.outline };
    });
    check("step 1 service card shows a ring/shadow when its radio is focus-visible",
      step1RingBox.boxShadow && step1RingBox.boxShadow !== "none");

    // Advance to step 2 (doctor) via the wizard's Next button
    await firstServiceLabel.click();
    await page.click('button[data-action*="booking-wizard#next"]');
    await page.waitForSelector('[data-booking-wizard-target="stepPanel"][data-step="2"]:not(.hidden)');

    const firstStaffLabel = page.locator('label:has(input[name="staff_id"])').first();
    await firstStaffLabel.locator('input[name="staff_id"]').focus();
    await page.screenshot({ path: screenshotPath("booking_step2_focus.png") });
    const step2RingBox = await firstStaffLabel.evaluate((el) => getComputedStyle(el).boxShadow);
    check("step 2 doctor card shows a ring/shadow when its radio is focus-visible",
      step2RingBox && step2RingBox !== "none");

    // --- Step 3: turbo-frame#slots[busy] loading dim ---
    await page.click('button[data-action*="booking-wizard#next"]');
    await page.waitForSelector('[data-booking-wizard-target="stepPanel"][data-step="3"]:not(.hidden)');

    // Pick the next weekday's date cell (first "available" one) to trigger a
    // real Turbo Frame navigation for the slots frame.
    const availableDateCell = page.locator('[data-booking-wizard-target="dateCell"]').filter({
      has: page.locator(".bg-green-500, [data-resting-class*='green']"),
    }).first();

    // Local dev responses are fast enough that [busy] can come and go inside
    // a couple of milliseconds. Throttle just this one navigation so the
    // loading state is actually observable instead of racing it.
    await page.route("**/clinics/*/booking?*date=*", async (route) => {
      await new Promise((resolve) => setTimeout(resolve, 800));
      await route.continue().catch(() => {}); // ignore double-handling on any retry
    });

    await availableDateCell.click();

    // Playwright's waitForSelector on a `[busy]` CSS attribute-presence
    // selector doesn't reliably catch this transient boolean attribute
    // (busy="" — empty-string attributes are valid HTML but a known rough
    // edge for some selector-engine matching); poll it directly instead.
    const slotsFrame = page.locator("turbo-frame#slots");
    let sawBusy = false;
    for (let i = 0; i < 10 && !sawBusy; i++) {
      const busyAttr = await slotsFrame.getAttribute("busy");
      if (busyAttr !== null) sawBusy = true;
      else await page.waitForTimeout(100);
    }
    check("turbo-frame#slots gets [busy] while fetching", sawBusy);

    if (sawBusy) {
      // The opacity change is CSS-transitioned over 0.15s — give it a beat
      // past that so we're reading the settled value, not mid-fade.
      await page.waitForTimeout(200);
      const opacity = await slotsFrame.evaluate((el) => getComputedStyle(el).opacity);
      check("slots frame is visibly dimmed (opacity 0.4) while [busy]", opacity === "0.4");
      await page.screenshot({ path: screenshotPath("booking_step3_loading.png") });
    }

    await page.unroute("**/clinics/*/booking?*date=*");

    await page.waitForSelector("turbo-frame#slots:not([busy])", { timeout: 5000 });
    await page.screenshot({ path: screenshotPath("booking_step3_loaded.png") });

    check("no console errors during the flow", consoleErrors.length === 0);
    if (consoleErrors.length > 0) console.log("  console errors:", consoleErrors);
  } finally {
    if (recordingVideo) {
      await closeAndSaveVideo(browser, context, "booking_ux_focus_and_loading");
    } else {
      await browser.close();
    }
  }

  summarize("booking_ux_focus_and_loading");
})();
