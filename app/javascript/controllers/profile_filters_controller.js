import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["filmsSearch", "photosSearch", "filmsSort", "filmType"]

  connect() {
    this.searchTimeout = null
    this.bindOverlayHandlers()
    this.restoreSearchFocus()
  }

  disconnect() {
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
    }
    this.unbindOverlayHandlers()
  }

  debouncedSearch(event) {
    const value = event.target.value
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
    }
    this.searchTimeout = setTimeout(() => {
      this.applySearch(value)
    }, 2000)
  }

  submitSearch(event) {
    if (event.key !== "Enter") return
    event.preventDefault()
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
    }
    this.applySearch(event.target.value)
  }

  changeFilters() {
    this.applyFilters()
  }

  applySearch(value) {
    const params = new URLSearchParams(window.location.search)
    const trimmed = (value || "").trim()

    if (trimmed) {
      params.set("q", trimmed)
    } else {
      params.delete("q")
    }

    params.delete("films_page")
    params.delete("photos_page")

    sessionStorage.setItem("profileSearchFocus", "true")

    const newUrl = window.location.pathname + (params.toString() ? `?${params}` : "")
    window.location.href = newUrl
  }

  applyFilters() {
    const params = new URLSearchParams(window.location.search)
    const searchValue = this.hasFilmsSearchTarget ? this.filmsSearchTarget.value.trim() : ""
    const sortValue = this.hasFilmsSortTarget ? this.filmsSortTarget.value : ""
    const typeValue = this.hasFilmTypeTarget ? this.filmTypeTarget.value : ""

    if (searchValue) {
      params.set("q", searchValue)
    } else {
      params.delete("q")
    }

    if (sortValue && sortValue !== "date_desc") {
      params.set("sort", sortValue)
    } else {
      params.delete("sort")
    }

    if (typeValue) {
      params.set("film_type", typeValue)
    } else {
      params.delete("film_type")
    }

    params.delete("films_page")

    const newUrl = window.location.pathname + (params.toString() ? `?${params}` : "")
    window.location.href = newUrl
  }

  restoreSearchFocus() {
    if (sessionStorage.getItem("profileSearchFocus") !== "true") {
      return
    }
    sessionStorage.removeItem("profileSearchFocus")

    const target = this.hasFilmsSearchTarget
      ? this.filmsSearchTarget
      : (this.hasPhotosSearchTarget ? this.photosSearchTarget : null)

    if (!target) return

    setTimeout(() => {
      target.focus()
      const length = target.value.length
      if (typeof target.setSelectionRange === "function") {
        target.setSelectionRange(length, length)
      }
    }, 100)
  }

  bindOverlayHandlers() {
    this.handleTurboClick = this.handleTurboClick.bind(this)
    this.hideOverlay = this.hideOverlay.bind(this)

    document.addEventListener("turbo:click", this.handleTurboClick)
    document.addEventListener("turbo:before-render", this.hideOverlay)
    document.addEventListener("turbo:render", this.hideOverlay)
    document.addEventListener("turbo:fetch-request-error", this.hideOverlay)
    document.addEventListener("turbo:load", this.hideOverlay)
    this.hideOverlay()
  }

  unbindOverlayHandlers() {
    document.removeEventListener("turbo:click", this.handleTurboClick)
    document.removeEventListener("turbo:before-render", this.hideOverlay)
    document.removeEventListener("turbo:render", this.hideOverlay)
    document.removeEventListener("turbo:fetch-request-error", this.hideOverlay)
    document.removeEventListener("turbo:load", this.hideOverlay)
  }

  handleTurboClick(event) {
    const clickedLink = event.target.closest("a")
    if (!clickedLink || !clickedLink.href.includes("/users/")) return

    const overlay = this.getOverlay()
    if (overlay) {
      overlay.classList.add("active")
    }
  }

  hideOverlay() {
    const overlay = this.getOverlay()
    if (overlay) {
      overlay.classList.remove("active")
    }
  }

  getOverlay() {
    return document.getElementById("profile-loading-overlay")
  }
}
