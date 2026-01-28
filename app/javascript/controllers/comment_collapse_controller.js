import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["replies", "icon"]

  toggle(event) {
    event.preventDefault()
    const btn = event.currentTarget
    const replies = this.repliesTarget

    if (replies && btn) {
      replies.classList.toggle('collapsed')
      btn.classList.toggle('collapsed')
    }
  }
}
