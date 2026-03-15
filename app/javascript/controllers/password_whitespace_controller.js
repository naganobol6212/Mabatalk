import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["warning"]

  check(event) {
    const hasWhitespace = /\s/.test(event.target.value)
    this.warningTarget.classList.toggle("hidden", !hasWhitespace)
  }
}
