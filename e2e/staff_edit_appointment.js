// Playwright smoke check for the staff appointment edit/reschedule/cancel flow
// (docs/admin_portal/11_appointment_details.md, simplified per user request:
// selecting an appointment goes straight to an edit form with Save, plus a
// Cancel Appointment action on the same page).
//
// Creates a throwaway patient + appointment via `bin/rails runner`, cleans it
// up in a `finally` block so a mid-run crash never leaves orphaned test data
// (see e2e/staff_add_doctor.js for why this pattern exists).
const { execSync } = require("child_process");
const { launch, closeAndSaveVideo, signIn } = require("./lib/browser");
const { check, summarize } = require("./lib/check");
const path = require("path");

const testEmail = `e2e-edit-patient-${Date.now()}@example.com`;
let apptId, isoDate;

function setup() {
  const setupScript = `
    patient = User.create!(email: "${testEmail}", password: "password123", password_confirmation: "password123", role: :patient, name: "E2E Edit Patient")
    clinic = User.find_by!(email: "owner@bookq.test").clinics.first
    service = clinic.services.find_by!(name: "General Check-up")
    date = Date.current.next_occurring(:monday)
    Availability.find_or_create_by!(clinic: clinic, day_of_week: :monday) { |a| a.start_time = "09:00"; a.end_time = "17:00" }
    appt = Appointment.create!(patient: patient, clinic: clinic, service: service, starts_at: date.in_time_zone.change(hour: 10), ends_at: date.in_time_zone.change(hour: 10, min: 30), status: :pending)
    puts "APPT_ID=#{appt.id}"
    puts "DATE=#{date.iso8601}"
  `;
  const output = execSync(`cd .. && bin/rails runner '${setupScript}'`, { encoding: "utf8" });
  apptId = output.match(/APPT_ID=(\d+)/)[1];
  isoDate = output.match(/DATE=([\d-]+)/)[1];
}

function cleanup() {
  try {
    execSync(
      `cd .. && bin/rails runner 'u = User.find_by(email: "${testEmail}"); u&.destroy'`,
      { stdio: "pipe" }
    );
    console.log("  cleanup: removed the throwaway patient + appointment");
  } catch (e) {
    console.log("  cleanup warning: could not remove throwaway test data —", e.message);
  }
}

(async () => {
  setup();
  const { browser, context, page, consoleErrors, baseUrl, recordingVideo } = await launch();
  const pause = () => page.waitForTimeout(recordingVideo ? 700 : 0);

  try {
    await signIn(page, baseUrl, "owner@bookq.test", "password123");
    await pause();

    await page.goto(`${baseUrl}/staff/appointments?date=${isoDate}`);
    await page.waitForURL(`${baseUrl}/staff/appointments?date=${isoDate}`, { timeout: 10000 });
    await pause();

    await page.click("text=E2E Edit Patient");
    await page.waitForURL(`${baseUrl}/staff/appointments/${apptId}/edit?date=${isoDate}`, { timeout: 10000 });
    await pause();

    check("clicking a list row opens the edit form", page.url() === `${baseUrl}/staff/appointments/${apptId}/edit?date=${isoDate}`);
    const prefill = await page.locator("body").innerText();
    check("edit form pre-fills the patient name", prefill.includes("E2E Edit Patient"));
    check("edit form pre-fills the current service", prefill.includes("General Check-up"));
    check("no <select> tags (radio-card convention)", await page.locator("select").count() === 0);

    const editFormScreenshot = path.join(__dirname, "screenshots", "staff_edit_appointment_form.png");
    await page.screenshot({ path: editFormScreenshot, fullPage: true });
    console.log(`  screenshot saved to ${editFormScreenshot}`);

    // Reschedule to a different time slot.
    await page.click('label:has-text("11:00 AM")');
    await page.fill('textarea[name="notes"]', "Rescheduled via e2e");
    await pause();
    await page.click('input[type="submit"][value="Save Changes"]');
    await page.waitForURL(`${baseUrl}/staff/appointments?date=${isoDate}`, { timeout: 10000 });
    await pause();

    check("saving redirects back to the appointments list", page.url() === `${baseUrl}/staff/appointments?date=${isoDate}`);
    const afterSave = await page.locator("body").innerText();
    check("list shows the new time (11:00 AM)", afterSave.includes("11:00 AM"));
    check("Appointment updated notice shown", afterSave.includes("Appointment updated"));

    // Cancel it.
    await page.click("text=E2E Edit Patient");
    await page.waitForURL(`${baseUrl}/staff/appointments/${apptId}/edit?date=${isoDate}`, { timeout: 10000 });
    await pause();
    await page.click('button:has-text("Cancel Appointment")');
    await page.locator('button[data-choice="ok"]').waitFor({ timeout: 5000 });
    await pause();
    await page.click('button[data-choice="ok"]');
    await page.waitForURL(`${baseUrl}/staff/appointments?date=${isoDate}`, { timeout: 10000 });
    await pause();

    check("cancelling redirects back to the list with a notice", (await page.locator("body").innerText()).includes("Appointment cancelled"));

    // A cancelled appointment shows a read-only notice, not the edit form.
    await page.goto(`${baseUrl}/staff/appointments/${apptId}/edit`);
    await pause();
    check("cancelled appointment shows a read-only notice instead of the edit form", (await page.locator("body").innerText()).includes("can no longer be edited"));

    check("no browser console/page errors", consoleErrors.length === 0);
    if (consoleErrors.length > 0) console.log("  console errors:", consoleErrors);

    const screenshotPath = path.join(__dirname, "screenshots", "staff_edit_appointment.png");
    await page.screenshot({ path: screenshotPath, fullPage: true });
    console.log(`  screenshot saved to ${screenshotPath}`);
    await pause();

    const videoPath = await closeAndSaveVideo(browser, context, "staff_edit_appointment");
    if (videoPath) console.log(`  video saved to ${videoPath}`);
  } finally {
    await browser.close().catch(() => {});
    cleanup();
  }

  summarize("staff_edit_appointment.js");
})();
