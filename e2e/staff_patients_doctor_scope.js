// Playwright smoke check for doctor-level patient scoping (DPA data
// minimization): a plain staff member (doctor) should only see patients who
// have an appointment with THEM specifically, not every patient booked
// anywhere at the clinic. The clinic owner still sees everyone.
//
// Creates a throwaway clinic with two doctors and two patients (one booked
// with each doctor) via `bin/rails runner`, cleaned up in a `finally` block
// (see e2e/staff_add_doctor.js for why).
// Usage: node e2e/staff_patients_doctor_scope.js
const { execSync } = require("child_process");
const { launch, closeAndSaveVideo, signIn } = require("./lib/browser");
const { check, summarize } = require("./lib/check");
const path = require("path");

const stamp = Date.now();
const ownerEmail = `e2e-scope-owner-${stamp}@example.com`;
const doctorAEmail = `e2e-scope-doctor-a-${stamp}@example.com`;
const doctorBEmail = `e2e-scope-doctor-b-${stamp}@example.com`;
const patientAEmail = `e2e-scope-patient-a-${stamp}@example.com`;
const patientBEmail = `e2e-scope-patient-b-${stamp}@example.com`;

function setup() {
  const setupScript = `
    owner = User.create!(email: "${ownerEmail}", password: "password123", password_confirmation: "password123", role: :staff, name: "Scope Test Owner")
    clinic = Clinic.create!(name: "Scope Test Clinic", address: "1 Test St.", phone: "0917-000-0000", owner: owner)
    ClinicStaff.create!(clinic: clinic, user: owner, role: :owner)

    doctor_a = User.create!(email: "${doctorAEmail}", password: "password123", password_confirmation: "password123", role: :staff, name: "Dr. Scope A")
    ClinicStaff.create!(clinic: clinic, user: doctor_a, role: :staff)
    doctor_b = User.create!(email: "${doctorBEmail}", password: "password123", password_confirmation: "password123", role: :staff, name: "Dr. Scope B")
    ClinicStaff.create!(clinic: clinic, user: doctor_b, role: :staff)

    service = Service.create!(clinic: clinic, name: "Scope Test Service", duration_minutes: 30, price: 500)

    patient_a = User.create!(email: "${patientAEmail}", password: "password123", password_confirmation: "password123", role: :patient, name: "Patient Of Doctor A")
    Appointment.create!(patient: patient_a, clinic: clinic, service: service, staff: doctor_a,
      starts_at: 1.day.from_now.change(hour: 10), ends_at: 1.day.from_now.change(hour: 10, min: 30), status: :pending)

    patient_b = User.create!(email: "${patientBEmail}", password: "password123", password_confirmation: "password123", role: :patient, name: "Patient Of Doctor B")
    Appointment.create!(patient: patient_b, clinic: clinic, service: service, staff: doctor_b,
      starts_at: 1.day.from_now.change(hour: 11), ends_at: 1.day.from_now.change(hour: 11, min: 30), status: :pending)

    puts "OK"
  `;
  execSync(`cd .. && bin/rails runner '${setupScript}'`, { encoding: "utf8" });
}

function cleanup() {
  try {
    execSync(
      `cd .. && bin/rails runner '` +
        `clinic = Clinic.find_by(name: "Scope Test Clinic"); ` +
        `clinic&.appointments&.destroy_all; ` + // Service has dependent: :restrict_with_error on
        `clinic&.destroy; ` +                   // appointments, which would otherwise block this.
        `User.where(email: ["${ownerEmail}", "${doctorAEmail}", "${doctorBEmail}", "${patientAEmail}", "${patientBEmail}"]).destroy_all'`,
      { stdio: "pipe" }
    );
    console.log("  cleanup: removed the throwaway clinic/doctors/patients");
  } catch (e) {
    console.log("  cleanup warning: could not remove throwaway test data —", e.message);
  }
}

(async () => {
  setup();
  const { browser, context, page, consoleErrors, baseUrl, recordingVideo } = await launch();
  const pause = () => page.waitForTimeout(recordingVideo ? 700 : 0);

  try {
    // Doctor A should only see Patient A.
    await signIn(page, baseUrl, doctorAEmail, "password123");
    await pause();
    await page.goto(`${baseUrl}/staff/patients`);
    await pause();

    let body = await page.locator("body").innerText();
    check("Dr. A sees their own patient", body.includes("Patient Of Doctor A"));
    check("Dr. A does NOT see Dr. B's patient (DPA data minimization)", !body.includes("Patient Of Doctor B"));

    await page.locator('button[data-action="staff-nav#open"]').first().click();
    await page.waitForTimeout(300);
    await page.click('button:has-text("Log out")');
    await page.waitForURL(`${baseUrl}/`, { timeout: 10000 });
    await pause();

    // Owner should see both patients.
    await signIn(page, baseUrl, ownerEmail, "password123");
    await pause();
    await page.goto(`${baseUrl}/staff/patients`);
    await pause();

    body = await page.locator("body").innerText();
    check("owner sees Dr. A's patient", body.includes("Patient Of Doctor A"));
    check("owner sees Dr. B's patient too (clinic-wide visibility)", body.includes("Patient Of Doctor B"));

    check("no browser console/page errors", consoleErrors.length === 0);
    if (consoleErrors.length > 0) console.log("  console errors:", consoleErrors);

    const screenshotPath = path.join(__dirname, "screenshots", "staff_patients_doctor_scope.png");
    await page.screenshot({ path: screenshotPath, fullPage: true });
    console.log(`  screenshot saved to ${screenshotPath}`);
    await pause();

    const videoPath = await closeAndSaveVideo(browser, context, "staff_patients_doctor_scope");
    if (videoPath) console.log(`  video saved to ${videoPath}`);
  } finally {
    await browser.close().catch(() => {});
    cleanup();
  }

  summarize("staff_patients_doctor_scope.js");
})();
