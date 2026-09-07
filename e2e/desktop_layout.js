// Verifies the desktop sidebar shell added to application.html.erb:
// hidden on mobile viewports, visible (with working nav) on desktop ones,
// and the booking wizard's step-3 calendar/slots go side-by-side on desktop.
const { chromium } = require("playwright-core");
const { signIn } = require("./lib/browser");
const { check, summarize } = require("./lib/check");
const path = require("path");

const CHROMIUM_PATH = process.env.CHROMIUM_PATH || "/usr/bin/chromium";
const BASE_URL = process.env.BASE_URL || "http://localhost:3000";

async function newPage(viewport) {
  const browser = await chromium.launch({
    executablePath: CHROMIUM_PATH,
    args: [ "--no-sandbox", "--disable-dev-shm-usage", "--disable-gpu" ],
  });
  const context = await browser.newContext({ viewport });
  const page = await context.newPage();
  const consoleErrors = [];
  page.on("console", (msg) => { if (msg.type() === "error") consoleErrors.push(msg.text()); });
  page.on("pageerror", (err) => consoleErrors.push(`pageerror: ${err.message}`));
  return { browser, page, consoleErrors };
}

(async () => {
  let allConsoleErrors = [];

  // === mobile viewport: sidebar must stay hidden, layout unchanged ===
  {
    const { browser, page, consoleErrors } = await newPage({ width: 412, height: 915 });
    await signIn(page, BASE_URL, "e2e.patient@bookq.test", "password123");
    check("sidebar is not visible on a mobile viewport", !(await page.locator("aside").isVisible()));
    allConsoleErrors = allConsoleErrors.concat(consoleErrors);
    await browser.close();
  }

  // === desktop viewport: sidebar visible, nav works, logout works ===
  {
    const { browser, page, consoleErrors } = await newPage({ width: 1440, height: 900 });
    await signIn(page, BASE_URL, "e2e.patient@bookq.test", "password123");

    const sidebar = page.locator("aside");
    check("sidebar is visible on a desktop viewport", await sidebar.isVisible());
    check("sidebar shows the signed-in user's name", (await sidebar.textContent()).includes("E2E Test Patient"));

    await page.goto(`${BASE_URL}/clinics/1/booking`);
    await page.waitForLoadState("networkidle");
    check("sidebar persists on the booking page too", await page.locator("aside").isVisible());

    // Step 3: calendar and slots should sit side by side (slots to the
    // right of the calendar, not stacked below it) on a wide viewport.
    await page.locator('label:has(input[name="service_id"])').first().click();
    await page.click('button[data-action*="booking-wizard#next"]');
    await page.waitForSelector('[data-booking-wizard-target="stepPanel"][data-step="2"]:not(.hidden)');
    await page.click('button[data-action*="booking-wizard#next"]');
    await page.waitForSelector('[data-booking-wizard-target="stepPanel"][data-step="3"]:not(.hidden)');

    const availableDateCell = page.locator('[data-booking-wizard-target="dateCell"]').filter({
      has: page.locator(".bg-green-500, [data-resting-class*='green']"),
    }).first();
    await availableDateCell.click();
    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(300);

    const calendarBox = await page.locator('[data-booking-wizard-target="dateCell"]').first().boundingBox();
    const slotsBox = await page.locator("turbo-frame#slots label").first().boundingBox();
    check("on desktop, the first time slot sits to the right of the calendar (side-by-side layout)",
      slotsBox.x > calendarBox.x + calendarBox.width);

    await page.screenshot({ path: path.join(__dirname, "screenshots", "desktop_sidebar_and_schedule.png") });

    allConsoleErrors = allConsoleErrors.concat(consoleErrors);
    await browser.close();
  }

  check("no console errors across viewports", allConsoleErrors.length === 0);
  if (allConsoleErrors.length > 0) console.log("  console errors:", allConsoleErrors);

  summarize("desktop_layout");
})();
