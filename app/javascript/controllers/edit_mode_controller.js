import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggleIcon", "toggleLabel", "editOnly"]

  toggle() {
    const nowEditing = this.element.dataset.editing !== "true"
    this.element.dataset.editing = nowEditing
    this.editOnlyTargets.forEach(el => el.classList.toggle("hidden", !nowEditing))
    this.toggleLabelTarget.textContent = nowEditing ? "完了" : "管理モード"
    this.toggleIconTarget.textContent = nowEditing ? "check_circle" : "settings"
  }
}
