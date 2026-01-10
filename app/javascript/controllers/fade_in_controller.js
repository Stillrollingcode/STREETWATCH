// app/javascript/controllers/fade_in_controller.js
// Stimulus controller for fading in images when they load

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image"]
  static classes = ["loaded"]

  connect() {
    // If there's no image target (placeholder only), show immediately
    if (!this.hasImageTarget) {
      this.element.classList.add(this.loadedClass || "thumbnail-loaded")
      return
    }

    // Check if image is already loaded (from cache or eager loaded)
    if (this.imageTarget.complete && this.imageTarget.naturalHeight !== 0) {
      this.imageLoaded()
    } else {
      // For lazy-loaded images, also set up intersection observer
      this.setupLazyLoadFallback()
    }
  }

  setupLazyLoadFallback() {
    // If image hasn't loaded after 100ms, show it anyway to prevent blank thumbnails
    this.timeout = setTimeout(() => {
      if (!this.element.classList.contains(this.loadedClass || "thumbnail-loaded")) {
        console.log("Fallback: showing image that didn't fire load event")
        this.imageLoaded()
      }
    }, 100)
  }

  imageLoaded() {
    // Clear timeout if it exists
    if (this.timeout) {
      clearTimeout(this.timeout)
    }

    // Add the loaded class to trigger fade-in animation
    this.element.classList.add(this.loadedClass || "thumbnail-loaded")
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }
}
