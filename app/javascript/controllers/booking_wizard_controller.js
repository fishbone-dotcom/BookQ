import { Controller } from "@hotwired/stimulus"

const CELL_BASE = "relative flex flex-col items-center justify-center h-11 rounded-lg text-sm"
const CELL_SELECTED = "bg-emerald-600 text-white font-semibold"

const CIRCLE_CLASSES = {
  reached: [ "bg-emerald-600", "text-white" ],
  upcoming: [ "bg-gray-100", "text-gray-400" ]
}
const ALL_CIRCLE_CLASSES = Object.values(CIRCLE_CLASSES).flat()

export default class extends Controller {
  static targets = [
    "stepPanel", "stepIndicator", "progressLine", "serviceForm", "bookingForm", "hiddenDate", "dateCell",
    "backButton", "nextButton", "submitButton", "summaryStaff", "summaryDate", "summaryTime"
  ]
  static values = { step: { type: Number, default: 1 } }

  stepValueChanged(value) {
    this.stepPanelTargets.forEach((el) => {
      el.classList.toggle("hidden", el.dataset.step !== String(value))
    })

    this.stepIndicatorTargets.forEach((el) => {
      const step = Number(el.dataset.step)
      const state = step <= value ? "reached" : "upcoming"
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
  }

  next() {
    if (this.stepValue === 1) {
      this.serviceFormTarget.requestSubmit()
      return
    }
    this.stepValue = Math.min(4, this.stepValue + 1)
  }

  back() {
    this.stepValue = Math.max(1, this.stepValue - 1)
  }

  selectDate(event) {
    const cell = event.currentTarget
    this.hiddenDateTarget.value = cell.dataset.date
    this.dateCellTargets.forEach((el) => this.paintDateCell(el, el === cell))
    this.nextButtonTarget.disabled = true
  }

  slotChanged() {
    this.nextButtonTarget.disabled = false
  }

  paintDateCell(el, selected) {
    el.className = `${CELL_BASE} ${selected ? CELL_SELECTED : el.dataset.restingClass}`
    const dot = el.querySelector(".avail-dot")
    if (dot) dot.className = `avail-dot w-1.5 h-1.5 rounded-full mt-0.5 ${selected ? "bg-white" : dot.dataset.restingClass}`
  }

  renderSummary() {
    const staffChecked = this.bookingFormTarget.querySelector('input[name="staff_id"]:checked')
    this.summaryStaffTarget.textContent = staffChecked?.dataset.name || "Kahit sino / Walang partikular"

    const dateCell = this.dateCellTargets.find((el) => el.dataset.date === this.hiddenDateTarget.value)
    this.summaryDateTarget.textContent = dateCell ? dateCell.dataset.label : "—"

    const timeChecked = this.bookingFormTarget.querySelector('input[name="starts_at"]:checked')
    this.summaryTimeTarget.textContent = timeChecked ? timeChecked.dataset.label : "—"
  }
}
