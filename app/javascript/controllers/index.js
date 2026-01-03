// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"

// Import controllers
import LazyLoadController from "controllers/lazy_load_controller"

// Register controllers
application.register("lazy-load", LazyLoadController)

console.log("Stimulus controllers registered")
