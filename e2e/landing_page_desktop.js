// Verifies the logged-out landing page hero renders as a real two-column
// layout on desktop viewports (text left, illustration right) rather than
// the mobile-style single centered column.
const { chromium } = require("playwright-core");
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

  await page.goto(`${BASE_URL}/`);
  await page.waitForLoadState("networkidle");

  const headlineBox = await page.locator("h1").first().boundingBox();
  const visualBox = await page.locator("h1").first().locator(
    "xpath=/ancestor::div[contains(@class,'lg:grid')][1]"
  ).locator("div.hidden.lg\\:block").boundingBox();

  check("hero illustration panel is visible on desktop", visualBox !== null);
  check("hero illustration sits to the right of the headline (two-column layout)",
    visualBox && visualBox.x > headlineBox.x + headlineBox.width);

  const body = await page.locator("body").textContent();
  check("hero still shows the schedule preview text", body.includes("Your appointment is booked instantly"));

  await page.screenshot({ path: path.join(__dirname, "screenshots", "landing_page_desktop.png"), fullPage: true });

  check("no console errors", consoleErrors.length === 0);
  if (consoleErrors.length > 0) console.log("  console errors:", consoleErrors);

  await browser.close();
  summarize("landing_page_desktop");
})();
