// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"

// Import controllers
import LazyLoadController from "controllers/lazy_load_controller"
import ProfileTabsController from "controllers/profile_tabs_controller"
import ActivityMenuController from "controllers/activity_menu_controller"
import ProfileFiltersController from "controllers/profile_filters_controller"
import UsersIndexController from "controllers/users_index_controller"
import FilmShowController from "controllers/film_show_controller"
import FilmsIndexController from "controllers/films_index_controller"

// Register controllers
application.register("lazy-load", LazyLoadController)
application.register("profile-tabs", ProfileTabsController)
application.register("activity-menu", ActivityMenuController)
application.register("profile-filters", ProfileFiltersController)
application.register("users-index", UsersIndexController)
application.register("film-show", FilmShowController)
application.register("films-index", FilmsIndexController)

console.log("Stimulus controllers registered")
