import { Controller } from "@hotwired/stimulus"

const CELL_BASE = "relative flex flex-col items-center justify-center h-11 rounded-lg text-sm"
const CELL_SELECTED = "bg-emerald-600 text-white font-semibold"

const CIRCLE_CLASSES = {
  reached: [ "bg-emerald-600", "text-white", "cursor-pointer" ],
  upcoming: [ "bg-gray-100", "text-gray-400", "cursor-default" ]
}
const ALL_CIRCLE_CLASSES = Object.values(CIRCLE_CLASSES).flat()

export default class extends Controller {
  static targets = [
    "stepPanel", "stepIndicator", "progressLine", "serviceForm", "staffForm", "staffFormStaffId",
    "bookingForm", "hiddenDate", "dateCell",
    "backButton", "nextButton", "submitButton",
    "summaryStaff", "summaryDate", "summaryTime",
    "summaryStaffPrevious", "summaryDatePrevious", "summaryTimePrevious"
  ]
  static values = {
    step: { type: Number, default: 1 },
    furthest: { type: Number, default: 1 },
    serviceId: String,
    previousStaff: String,
    previousDate: String,
    previousTime: String
  }

  initialize() {
    // Stimulus fires the initial stepValueChanged (and its persistState call)
    // before connect() runs. Without this guard that first call would
    // overwrite sessionStorage with blank state right before restoreState()
    // gets a chance to read it back.
    this.ready = false
  }

  connect() {
    this.restoreState()
    this.ready = true
  }

  stepValueChanged(value) {
    if (value > this.furthestValue) this.furthestValue = value

    this.stepPanelTargets.forEach((el) => {
      el.classList.toggle("hidden", el.dataset.step !== String(value))
    })

    this.stepIndicatorTargets.forEach((el) => {
      const step = Number(el.dataset.step)
      const state = step <= this.furthestValue ? "reached" : "upcoming"
      const circle = el.querySelector(".step-circle")
      circle.classList.remove(...ALL_CIRCLE_CLASSES)
      circle.classList.add(...CIRCLE_CLASSES[state])
    })
    this.progressLineTarget.style.width = `${((value - 1) / 3) * 75}%`

    this.backButtonTarget.classList.toggle("hidden", value === 1)
    this.nextButtonTarget.classList.toggle("hidden", value === 4)
    this.submitButtonTarget.classList.toggle("hidden", value !== 4)

    if (value === 3) {
      const hasTime = !!this.bookingFormTarget.querySelector('input[name="starts_at"]:checked')
      this.nextButtonTarget.disabled = !(this.hiddenDateTarget.value && hasTime)
    } else {
      this.nextButtonTarget.disabled = false
    }

    if (value === 4) this.renderSummary()
    this.persistState()
  }

  next() {
    if (this.stepValue === 1) {
      this.serviceFormTarget.requestSubmit()
      return
    }
    if (this.stepValue === 2) {
      // The doctor choice needs a real reload — the server has to know which
      // doctor was picked before it can compute that doctor's own slots.
      const staffChecked = this.bookingFormTarget.querySelector('input[name="staff_id"]:checked')
      this.staffFormStaffIdTarget.value = staffChecked?.value || ""
      this.staffFormTarget.requestSubmit()
      return
    }
    this.stepValue = Math.min(4, this.stepValue + 1)
  }

  back() {
    this.stepValue = Math.max(1, this.stepValue - 1)
  }

  // Lets a user tap an earlier step's circle to jump straight back to it,
  // instead of clicking "Back" repeatedly. Can't skip ahead to a step not
  // yet reached — that would bypass the step's own validation (e.g. jumping
  // to Confirm without a time picked).
  jumpTo(event) {
    const step = Number(event.currentTarget.dataset.step)
    if (step > this.furthestValue) return
    this.stepValue = step
  }

  selectDate(event) {
    const cell = event.currentTarget
    this.hiddenDateTarget.value = cell.dataset.date
    this.dateCellTargets.forEach((el) => this.paintDateCell(el, el === cell))
    this.nextButtonTarget.disabled = true
    this.persistState()
  }

  slotChanged() {
    this.nextButtonTarget.disabled = false
    this.persistState()
  }

  staffChanged() {
    this.persistState()
  }

  paintDateCell(el, selected) {
    el.className = `${CELL_BASE} ${selected ? CELL_SELECTED : el.dataset.restingClass}`
    const dot = el.querySelector(".avail-dot")
    if (dot) dot.className = `avail-dot w-1.5 h-1.5 rounded-full mt-0.5 ${selected ? "bg-white" : dot.dataset.restingClass}`
  }

  renderSummary() {
    const staffChecked = this.bookingFormTarget.querySelector('input[name="staff_id"]:checked')
    const newStaff = staffChecked?.dataset.name || "Anyone / No preference"
    this.summaryStaffTarget.textContent = newStaff
    this.showPrevious(this.summaryStaffPreviousTarget, this.previousStaffValue, newStaff)

    const dateCell = this.dateCellTargets.find((el) => el.dataset.date === this.hiddenDateTarget.value)
    const newDate = dateCell ? dateCell.dataset.label : "—"
    this.summaryDateTarget.textContent = newDate
    this.showPrevious(this.summaryDatePreviousTarget, this.previousDateValue, newDate)

    const timeChecked = this.bookingFormTarget.querySelector('input[name="starts_at"]:checked')
    const newTime = timeChecked ? timeChecked.dataset.label : "—"
    this.summaryTimeTarget.textContent = newTime
    this.showPrevious(this.summaryTimePreviousTarget, this.previousTimeValue, newTime)
  }

  // Shows "was: <old value>" under a summary row when rescheduling actually
  // changed that field, so a returning patient can see what's different at
  // a glance instead of only the new values.
  showPrevious(el, previousValue, newValue) {
    if (previousValue && previousValue !== newValue) {
      el.textContent = `was: ${previousValue}`
      el.hidden = false
    } else {
      el.hidden = true
    }
  }

  // Persists just enough (doctor + date, not the specific time slot — that
  // depends on slots freshly fetched for that date) so an accidental reload
  // doesn't send the patient all the way back to step 1. Scoped to this
  // clinic+service via the URL path and serviceIdValue so it never leaks
  // into a different booking.
  get storageKey() {
    return `booking-wizard:${window.location.pathname}`
  }

  persistState() {
    if (!this.ready) return

    const staffChecked = this.bookingFormTarget.querySelector('input[name="staff_id"]:checked')
    sessionStorage.setItem(this.storageKey, JSON.stringify({
      serviceId: this.serviceIdValue,
      staffId: staffChecked?.value || "",
      date: this.hiddenDateTarget.value,
      step: this.stepValue
    }))
  }

  clearStorage() {
    sessionStorage.removeItem(this.storageKey)
  }

  restoreState() {
    // Only intervene when the server hasn't already resolved a real date —
    // step 3 can be reached either because a date is genuinely set
    // server-side (an editing_appointment's date, or a date query param —
    // real state we shouldn't override) or just because the doctor step was
    // submitted (no date resolved yet, the case this restore is actually
    // for). Check the hidden date field itself rather than the step number,
    // since both cases render step 3.
    if (this.hiddenDateTarget.value) return

    let saved
    try {
      saved = JSON.parse(sessionStorage.getItem(this.storageKey) || "null")
    } catch {
      saved = null
    }
    if (!saved || saved.serviceId !== this.serviceIdValue) return

    if (saved.staffId) {
      const input = this.bookingFormTarget.querySelector(`input[name="staff_id"][value="${CSS.escape(saved.staffId)}"]`)
      if (input) input.checked = true
    }

    if (saved.date) {
      const cell = this.dateCellTargets.find((el) => el.dataset.date === saved.date)
      if (cell) {
        // Re-triggers the same Turbo Frame navigation a real click would, so
        // the slots for that date get freshly fetched rather than guessed at.
        cell.click()
        this.stepValue = 3
      }
    }
    // No further fallback beyond this — the server-computed stepValue this
    // connect() already fired with (from the URL's own service_id/staff_step)
    // is authoritative. Re-applying saved.step here would risk dragging a
    // freshly-advanced step backward with stale progress from an earlier page.
  }
}
