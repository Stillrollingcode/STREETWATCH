// Load all the controllers within this directory and all subdirectories.
// Controller files must be named *_controller.js.

import { Application } from "@hotwired/stimulus"
import { registerControllers } from "stimulus-vite-helpers"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

export { application }

// Simple stub for eagerLoadControllersFrom since we're not using it yet
export function eagerLoadControllersFrom(path, application) {
  // Controllers will be loaded here when needed
}
