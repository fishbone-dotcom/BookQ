// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

Turbo.config.forms.confirm = (message) => {
  return new Promise((resolve) => {
    const dialog = document.createElement("dialog")
    dialog.className = "m-auto rounded-xl p-6 backdrop:bg-black/40 w-11/12 max-w-sm"
    dialog.innerHTML = `
      <p class="text-gray-900 text-sm mb-5">${message}</p>
      <div class="flex gap-3">
        <button type="button" data-choice="discard" class="flex-1 border border-gray-300 text-gray-700 font-medium py-2 rounded-lg cursor-pointer hover:bg-gray-50">I-discard</button>
        <button type="button" data-choice="ok" class="flex-1 bg-emerald-600 hover:bg-emerald-700 text-white font-medium py-2 rounded-lg cursor-pointer">OK</button>
      </div>
    `

    dialog.addEventListener("click", (event) => {
      const choice = event.target.dataset.choice
      if (!choice) return
      dialog.close()
      resolve(choice === "ok")
    })
    dialog.addEventListener("close", () => dialog.remove())

    document.body.appendChild(dialog)
    dialog.showModal()
  })
}
