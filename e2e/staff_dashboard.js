// Playwright smoke check for docs/admin_portal/01_dashboard.md.
// Usage: node e2e/staff_dashboard.js  (see e2e/README.md for setup)
const { launch, signIn } = require("./lib/browser");
const { check, summarize } = require("./lib/check");
const path = require("path");

(async () => {
  const { browser, page, consoleErrors, baseUrl } = await launch();

  // 1. Unauthenticated visitors are sent to sign in.
  await page.goto(`${baseUrl}/staff/dashboard`);
  await page.waitForLoadState("networkidle");
  check("unauthenticated visit redirects to sign in", page.url().includes("/users/sign_in"));

  // 2. A patient (not clinic staff) is bounced back to the home page.
  await signIn(page, baseUrl, "patient@bookq.test", "password123");
  await page.goto(`${baseUrl}/staff/dashboard`);
  await page.waitForLoadState("networkidle");
  check("patient-role user is redirected away from the staff dashboard", page.url() === `${baseUrl}/`);
  await page.click('button:has-text("Log out")');
  await page.waitForLoadState("networkidle");

  // 3. A clinic staffer sees their dashboard.
  await signIn(page, baseUrl, "owner@bookq.test", "password123");
  await page.goto(`${baseUrl}/staff/dashboard`);
  await page.waitForLoadState("networkidle");
  await page.waitForTimeout(300);

  check("staff dashboard loads at the right URL", page.url() === `${baseUrl}/staff/dashboard`);
  check("header shows 'Dashboard'", await page.locator("h1", { hasText: "Dashboard" }).count() > 0);
  check("greeting includes the staffer's name", (await page.locator("body").innerText()).includes("Dr. Maria Santos"));

  const statLabels = [ "Today's Appointments", "Total Patients", "Doctors", "New Patients (This Month)" ];
  for (const label of statLabels) {
    check(`stat card "${label}" is present`, await page.locator(`text=${label}`).count() > 0);
  }

  // Regression check for the Tailwind-not-rebuilt bug hit while building this page:
  // the bottom tab bar must actually be pinned to the bottom of the viewport,
  // not collapsed near the top with un-compiled utility classes.
  const nav = page.locator("nav").last();
  const navBox = await nav.boundingBox();
  const viewport = page.viewportSize();
  check(
    "bottom tab bar is actually docked at the bottom of the viewport",
    navBox && viewport && navBox.y + navBox.height >= viewport.height - 5
  );
  check("bottom tab bar spans the full width", navBox && viewport && navBox.width >= viewport.width - 5);

  const navItems = await nav.locator("a, span").allInnerTexts();
  check("bottom tab bar lists all four sections", [ "Dashboard", "Appointments", "Patients", "More" ].every((label) => navItems.some((t) => t.includes(label))));

  check("no browser console/page errors", consoleErrors.length === 0);
  if (consoleErrors.length > 0) console.log("  console errors:", consoleErrors);

  const screenshotPath = path.join(__dirname, "screenshots", "staff_dashboard.png");
  await page.screenshot({ path: screenshotPath, fullPage: true });
  console.log(`  screenshot saved to ${screenshotPath}`);

  await browser.close();
  summarize("staff_dashboard.js");
})();
