import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "item", "empty" ]

  filter() {
    const query = this.inputTarget.value.trim().toLowerCase()
    let visibleCount = 0

    this.itemTargets.forEach((item) => {
      const matches = item.dataset.clinicSearchName.includes(query)
      item.classList.toggle("hidden", !matches)
      if (matches) visibleCount++
    })

    if (this.hasEmptyTarget) {
      this.emptyTarget.classList.toggle("hidden", visibleCount > 0)
    }
  }
}
