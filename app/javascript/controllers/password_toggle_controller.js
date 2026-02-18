import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "icon"]

  toggle() {
    const isHidden = this.inputTarget.type === "password"
    this.inputTarget.type = isHidden ? "text" : "password"
    this.iconTarget.textContent = isHidden ? "visibility" : "visibility_off"
  }
}
