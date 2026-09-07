// Manual/e2e verification for the appointment audit trail: the staff edit
// page's History section renders past created/rescheduled/cancelled
// entries with the right actor and reason, in reverse-chronological order.
const { launch, signIn } = require("./lib/browser");
const { check, summarize } = require("./lib/check");
const path = require("path");

(async () => {
  const { browser, page, baseUrl, consoleErrors } = await launch();

  await signIn(page, baseUrl, "audit-verify-owner@example.com", "password123");
  await page.goto(`${baseUrl}/staff/appointments/162/edit`);
  await page.waitForLoadState("networkidle");

  const body = await page.locator("body").textContent();
  check("History section is present", body.includes("History"));
  check("shows the Created entry with the patient as actor", /Created\s*by\s*Audit Patient/.test(body));
  check("shows the Rescheduled entry with the owner as actor", /Rescheduled\s*by\s*Audit Owner/.test(body));
  check("shows the Cancelled entry with the owner as actor and the reason", /Cancelled\s*by\s*Audit Owner/.test(body));
  check("shows the cancellation reason text", body.includes("Patient requested by phone"));

  // Reverse-chronological: Cancelled (most recent) should appear before
  // Created (oldest) in the raw text order.
  const cancelledIndex = body.indexOf("Cancelled");
  const createdIndex = body.indexOf("Created");
  check("entries are ordered most-recent first", cancelledIndex >= 0 && createdIndex >= 0 && cancelledIndex < createdIndex);

  await page.screenshot({ path: path.join(__dirname, "screenshots", "verify_audit_trail.png") });

  check("no console errors", consoleErrors.length === 0);
  if (consoleErrors.length > 0) console.log("  console errors:", consoleErrors);

  await browser.close();
  summarize("verify_audit_trail");
})();
