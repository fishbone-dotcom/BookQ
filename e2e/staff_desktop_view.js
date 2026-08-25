// Playwright visual check: staff console centered correctly on a desktop
// viewport, not just mobile. Per user request — keep the existing mobile
// card layout as-is, just make sure it centers on wide screens instead of
// having fixed-positioned elements (bottom tab bar, floating + button)
// stick to the true browser edges while content stays in a narrow centered
// column in the middle.
// Usage: node e2e/staff_desktop_view.js
const { chromium } = require("playwright-core");
const { signIn } = require("./lib/browser");
const { check, summarize } = require("./lib/check");
const path = require("path");

const CHROMIUM_PATH = process.env.CHROMIUM_PATH || "/usr/bin/chromium";
const BASE_URL = process.env.BASE_URL || "http://localhost:3000";

(async () => {
  const browser = await chromium.launch({
    executablePath: CHROMIUM_PATH,
    args: [ "--no-sandbox", "--disable-dev-shm-usage", "--disable-gpu" ],
  });
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await context.newPage();
  const consoleErrors = [];
  page.on("console", (msg) => { if (msg.type() === "error") consoleErrors.push(msg.text()); });
  page.on("pageerror", (err) => consoleErrors.push(`pageerror: ${err.message}`));

  await signIn(page, BASE_URL, "owner@bookq.test", "password123");

  const dashboardBox = await page.locator("h1", { hasText: "Dashboard" }).first().boundingBox();
  check("Dashboard header sits away from the left edge (centered column, not full-bleed)", dashboardBox.x > 400);

  const bottomNav = page.locator("nav.fixed.bottom-0");
  const navBox = await bottomNav.boundingBox();
  check("bottom tab bar is width-capped (max-w-md), not spanning the full 1440px viewport", navBox.width < 500);
  check("bottom tab bar is centered, not pinned to the left edge", navBox.x > 400);

  await page.screenshot({ path: path.join(__dirname, "screenshots", "staff_desktop_dashboard.png") });

  // Calendar page — floating "+" button anchoring check.
  await page.goto(`${BASE_URL}/staff/calendar`);
  await page.waitForLoadState("networkidle");
  const fab = page.locator('a[href^="/staff/appointments/new"]');
  const fabBox = await fab.boundingBox();
  check("Calendar's floating + button sits near the centered column's right edge, not the browser's true right edge", fabBox.x < 900);
  await page.screenshot({ path: path.join(__dirname, "screenshots", "staff_desktop_calendar.png") });

  // Patients page.
  await page.goto(`${BASE_URL}/staff/patients`);
  await page.waitForLoadState("networkidle");
  await page.screenshot({ path: path.join(__dirname, "screenshots", "staff_desktop_patients.png") });

  check("no browser console/page errors", consoleErrors.length === 0);
  if (consoleErrors.length > 0) console.log("  console errors:", consoleErrors);

  console.log("  screenshots saved to e2e/screenshots/staff_desktop_*.png");
  await browser.close();
  summarize("staff_desktop_view.js");
})();
