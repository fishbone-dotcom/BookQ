let failures = 0;
let passes = 0;

function check(description, condition) {
  if (condition) {
    passes += 1;
    console.log(`  ok — ${description}`);
  } else {
    failures += 1;
    console.log(`  FAIL — ${description}`);
  }
}

function summarize(scriptName) {
  console.log(`\n${scriptName}: ${passes} passed, ${failures} failed`);
  if (failures > 0) process.exitCode = 1;
}

module.exports = { check, summarize };
