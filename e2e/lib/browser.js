const { chromium } = require("playwright-core");
const path = require("path");
const fs = require("fs");

const CHROMIUM_PATH = process.env.CHROMIUM_PATH || "/usr/bin/chromium";
const BASE_URL = process.env.BASE_URL || "http://localhost:3000";
const RECORD_VIDEO = !!process.env.RECORD_VIDEO;
const VIDEO_DIR = path.join(__dirname, "..", "videos");

async function launch() {
  const browser = await chromium.launch({
    executablePath: CHROMIUM_PATH,
    args: [ "--no-sandbox", "--disable-dev-shm-usage", "--disable-gpu" ],
  });

  const contextOptions = { viewport: { width: 412, height: 915 } };
  if (RECORD_VIDEO) {
    fs.mkdirSync(VIDEO_DIR, { recursive: true });
    contextOptions.recordVideo = { dir: VIDEO_DIR, size: { width: 412, height: 915 } };
  }
  const context = await browser.newContext(contextOptions);
  const page = await context.newPage();

  const consoleErrors = [];
  page.on("console", (msg) => { if (msg.type() === "error") consoleErrors.push(msg.text()); });
  page.on("pageerror", (err) => consoleErrors.push(`pageerror: ${err.message}`));

  return { browser, context, page, consoleErrors, baseUrl: BASE_URL, recordingVideo: RECORD_VIDEO };
}

// Call instead of browser.close() directly when a script wants its video
// saved under a predictable name (Playwright names it with a random hash).
async function closeAndSaveVideo(browser, context, name) {
  if (!RECORD_VIDEO) {
    await browser.close();
    return null;
  }

  const video = context.pages()[0]?.video();
  await context.close();
  await browser.close();
  if (!video) return null;

  const generatedPath = await video.path();
  const finalPath = path.join(VIDEO_DIR, `${name}.webm`);
  fs.renameSync(generatedPath, finalPath);
  return finalPath;
}

async function signIn(page, baseUrl, email, password) {
  await page.goto(`${baseUrl}/users/sign_in`);
  await page.fill("#user_email", email);
  await page.fill("#user_password", password);
  await page.click('input[type="submit"]');
  await page.waitForLoadState("networkidle");
}

module.exports = { launch, closeAndSaveVideo, signIn, BASE_URL };
