import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["searchInput", "results", "sortSelect", "groupSelect"]

  connect() {
    this.searchTimeout = null
    this.autocompleteTimeout = null
    this.handleDocumentClick = this.handleDocumentClick.bind(this)

    document.addEventListener("click", this.handleDocumentClick)
    this.restoreSearchFocus()
  }

  disconnect() {
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
    }
    if (this.autocompleteTimeout) {
      clearTimeout(this.autocompleteTimeout)
    }
    document.removeEventListener("click", this.handleDocumentClick)
  }

  handleInput(event) {
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
    }
    this.searchTimeout = setTimeout(() => {
      this.applyFilters()
    }, 2000)

    this.updateAutocomplete(event.target.value)
  }

  handleKeydown(event) {
    if (event.key !== "Enter") return
    event.preventDefault()
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
    }
    this.applyFilters()
  }

  handleSelectChange() {
    this.applyFilters()
  }

  selectAutocomplete(event) {
    const item = event.target.closest(".autocomplete-result-item")
    if (!item || !this.hasResultsTarget) return

    const searchValue = item.dataset.searchValue || ""
    this.resultsTarget.classList.remove("show")
    this.navigateWithQuery(searchValue)
  }

  handleDocumentClick(event) {
    if (!this.hasSearchInputTarget || !this.hasResultsTarget) return
    if (!this.searchInputTarget.contains(event.target) && !this.resultsTarget.contains(event.target)) {
      this.resultsTarget.classList.remove("show")
    }
  }

  restoreSearchFocus() {
    if (sessionStorage.getItem("photosSearchFocus") !== "true") {
      return
    }
    sessionStorage.removeItem("photosSearchFocus")

    if (!this.hasSearchInputTarget) return

    setTimeout(() => {
      this.searchInputTarget.focus()
      const length = this.searchInputTarget.value.length
      if (typeof this.searchInputTarget.setSelectionRange === "function") {
        this.searchInputTarget.setSelectionRange(length, length)
      }
    }, 100)
  }

  applyFilters() {
    if (!this.hasSearchInputTarget) return

    const params = new URLSearchParams()
    const searchValue = this.searchInputTarget.value.trim()
    const sortValue = this.hasSortSelectTarget ? this.sortSelectTarget.value : ""
    const groupValue = this.hasGroupSelectTarget ? this.groupSelectTarget.value : ""

    if (searchValue) {
      params.set("search", searchValue)
    }
    if (sortValue) {
      params.set("sort", sortValue)
    }
    if (groupValue) {
      params.set("group_by", groupValue)
    }

    params.delete("page")
    sessionStorage.setItem("photosSearchFocus", "true")

    const queryString = params.toString()
    window.location.href = window.location.pathname + (queryString ? `?${queryString}` : "")
  }

  navigateWithQuery(valueOverride) {
    if (!this.hasSearchInputTarget) return
    this.searchInputTarget.value = valueOverride || ""
    this.applyFilters()
  }

  updateAutocomplete(query) {
    if (!this.hasResultsTarget) return

    const trimmed = (query || "").trim()
    if (trimmed.length < 2) {
      this.resultsTarget.classList.remove("show")
      this.resultsTarget.innerHTML = ""
      return
    }

    if (this.autocompleteTimeout) {
      clearTimeout(this.autocompleteTimeout)
    }

    this.autocompleteTimeout = setTimeout(() => {
      fetch(`/photos/autocomplete.json?q=${encodeURIComponent(trimmed)}`)
        .then(response => (response.ok ? response.json() : []))
        .then(results => {
          if (!results.length) {
            this.resultsTarget.innerHTML = "<div class=\"autocomplete-result-item\">No matches</div>"
            this.resultsTarget.classList.add("show")
            return
          }

          this.resultsTarget.innerHTML = results.map(item => (
            `<div class="autocomplete-result-item" data-search-value="${this.escapeHtml(item.value)}">
              <span class="autocomplete-result-username">${this.escapeHtml(item.label)}</span>
              <span class="autocomplete-result-type">${this.escapeHtml(item.type)}</span>
            </div>`
          )).join("")
          this.resultsTarget.classList.add("show")
        })
        .catch(() => {
          this.resultsTarget.classList.remove("show")
        })
    }, 150)
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
