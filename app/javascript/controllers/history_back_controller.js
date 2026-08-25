import { Controller } from "@hotwired/stimulus"

// Real browser history back, not a server-rendered request.referer link —
// Turbo Drive caches visited pages by URL, so a referer baked into a page's
// HTML on first visit gets served stale from cache on a later visit from a
// different page, sending "Back" to the wrong place.
export default class extends Controller {
  back(event) {
    event.preventDefault()
    history.back()
  }
}
