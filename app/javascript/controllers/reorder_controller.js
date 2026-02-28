import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  moveUp(event) {
    const card = event.currentTarget.closest("[data-reorder-card]")
    const prev = card.previousElementSibling
    if (!prev) return
    card.parentElement.insertBefore(card, prev)
    this.save()
  }

  moveDown(event) {
    const card = event.currentTarget.closest("[data-reorder-card]")
    const next = card.nextElementSibling
    if (!next) return
    card.parentElement.insertBefore(next, card)
    this.save()
  }

  save() {
    const ids = [...this.element.querySelectorAll("[data-reorder-card][data-id]")]
      .map(el => el.dataset.id)
      .filter(Boolean)

    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ ids })
    })
  }
}
