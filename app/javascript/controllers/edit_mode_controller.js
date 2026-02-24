import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggleIcon", "toggleLabel", "toggleButton", "editOnly"]

  toggle() {
    const nowEditing = this.element.dataset.editing !== "true"
    this.element.dataset.editing = nowEditing
    this.editOnlyTargets.forEach(el => el.classList.toggle("hidden", !nowEditing))
    if (this.hasToggleLabelTarget) {
      this.toggleLabelTarget.textContent = nowEditing ? "完了" : "編集する"
    }
    if (this.hasToggleIconTarget) {
      this.toggleIconTarget.textContent = nowEditing ? "check_circle" : "edit"
    }
    if (this.hasToggleButtonTarget) {
      this.toggleButtonTarget.setAttribute("aria-pressed", nowEditing.toString())
    }
  }
}
