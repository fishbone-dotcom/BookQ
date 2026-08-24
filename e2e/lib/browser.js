const { chromium } = require("playwright-core");

const CHROMIUM_PATH = process.env.CHROMIUM_PATH || "/usr/bin/chromium";
const BASE_URL = process.env.BASE_URL || "http://localhost:3000";

async function launch() {
  const browser = await chromium.launch({
    executablePath: CHROMIUM_PATH,
    args: [ "--no-sandbox", "--disable-dev-shm-usage", "--disable-gpu" ],
  });
  const page = await browser.newPage({ viewport: { width: 412, height: 915 } });

  const consoleErrors = [];
  page.on("console", (msg) => { if (msg.type() === "error") consoleErrors.push(msg.text()); });
  page.on("pageerror", (err) => consoleErrors.push(`pageerror: ${err.message}`));

  return { browser, page, consoleErrors, baseUrl: BASE_URL };
}

async function signIn(page, baseUrl, email, password) {
  await page.goto(`${baseUrl}/users/sign_in`);
  await page.fill("#user_email", email);
  await page.fill("#user_password", password);
  await page.click('input[type="submit"]');
  await page.waitForLoadState("networkidle");
}

module.exports = { launch, signIn, BASE_URL };
