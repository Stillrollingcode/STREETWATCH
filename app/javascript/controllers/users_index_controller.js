import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["searchInput", "results"]

  connect() {
    this.searchTimeout = null
    this.autocompleteTimeout = null
    this.followSyncState = new WeakMap()
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
      this.navigateWithQuery()
    }, 2000)

    this.updateAutocomplete(event.target.value)
  }

  handleKeydown(event) {
    if (event.key !== "Enter") return
    event.preventDefault()
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
    }
    this.navigateWithQuery()
  }

  selectAutocomplete(event) {
    const item = event.target.closest(".autocomplete-result-item")
    if (!item || !this.hasResultsTarget) return

    const searchValue = item.dataset.searchValue || ""
    this.resultsTarget.classList.remove("show")
    this.navigateWithQuery(searchValue)
  }

  handleFollowSubmit(event) {
    const form = event.target
    if (!form || !form.matches("form[data-follow-toggle=\"true\"]")) return

    event.preventDefault()
    const state = this.getFollowSyncState(form)
    const nextState = form.dataset.following !== "true"

    state.desired = nextState
    this.setFollowState(form, nextState)
    this.scheduleFollowSync(form, state)
  }

  handleDocumentClick(event) {
    if (!this.hasSearchInputTarget || !this.hasResultsTarget) return
    if (!this.searchInputTarget.contains(event.target) && !this.resultsTarget.contains(event.target)) {
      this.resultsTarget.classList.remove("show")
    }
  }

  restoreSearchFocus() {
    if (sessionStorage.getItem("profilesSearchFocus") !== "true") {
      return
    }
    sessionStorage.removeItem("profilesSearchFocus")

    if (!this.hasSearchInputTarget) return

    setTimeout(() => {
      this.searchInputTarget.focus()
      const length = this.searchInputTarget.value.length
      if (typeof this.searchInputTarget.setSelectionRange === "function") {
        this.searchInputTarget.setSelectionRange(length, length)
      }
    }, 60)
  }

  navigateWithQuery(valueOverride) {
    if (!this.hasSearchInputTarget) return

    const params = new URLSearchParams(window.location.search)
    const value = (valueOverride !== undefined ? valueOverride : this.searchInputTarget.value).trim()

    if (value) {
      params.set("q", value)
    } else {
      params.delete("q")
    }

    params.delete("page")
    sessionStorage.setItem("profilesSearchFocus", "true")

    const newUrl = window.location.pathname + (params.toString() ? `?${params}` : "")
    window.location.href = newUrl
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
      fetch(`/users.json?q=${encodeURIComponent(trimmed)}`)
        .then(response => (response.ok ? response.json() : []))
        .then(users => {
          const filtered = users.filter(user => this.userMatchesQuery(user, trimmed))
          if (filtered.length === 0) {
            this.resultsTarget.innerHTML = "<div class=\"autocomplete-result-item\">No matches</div>"
            this.resultsTarget.classList.add("show")
            return
          }

          this.resultsTarget.innerHTML = filtered.slice(0, 8).map(user => (
            `<div class="autocomplete-result-item" data-search-value="${user.name || user.username}">
              <span class="autocomplete-result-username">${user.username || user.name}</span>
              <span class="autocomplete-result-type">${user.name || ""}</span>
            </div>`
          )).join("")
          this.resultsTarget.classList.add("show")
        })
        .catch(() => {
          this.resultsTarget.classList.remove("show")
        })
    }, 150)
  }

  userMatchesQuery(user, query) {
    const queryLower = query.toLowerCase()
    const username = (user.username || "").toLowerCase()
    const name = (user.name || "").toLowerCase()

    if (username.includes(queryLower) || name.includes(queryLower)) {
      return true
    }

    const compactQuery = this.normalizeSearchValue(queryLower)
    if (!compactQuery) {
      return false
    }

    return this.normalizeSearchValue(username).includes(compactQuery) ||
      this.normalizeSearchValue(name).includes(compactQuery)
  }

  normalizeSearchValue(value) {
    return (value || "").toLowerCase().replace(/[^a-z0-9]/g, "")
  }

  getFollowSyncState(form) {
    let state = this.followSyncState.get(form)
    if (!state) {
      const initial = form.dataset.following === "true"
      state = {
        desired: initial,
        confirmed: initial,
        timer: null,
        inFlight: false,
        needsSync: false
      }
      this.followSyncState.set(form, state)
    }
    return state
  }

  scheduleFollowSync(form, state) {
    if (state.timer) clearTimeout(state.timer)
    state.timer = setTimeout(() => {
      state.timer = null
      this.syncFollowState(form)
    }, 200)
  }

  syncFollowState(form) {
    const state = this.getFollowSyncState(form)

    if (state.inFlight) {
      state.needsSync = true
      return
    }

    if (state.confirmed === state.desired) return

    const targetState = state.desired
    const followUrl = form.dataset.followUrl || form.getAttribute("action")
    const unfollowUrl = form.dataset.unfollowUrl || form.getAttribute("action")
    const requestUrl = targetState ? followUrl : unfollowUrl
    const requestMethod = targetState ? "POST" : "DELETE"
    const csrfToken = this.getCsrfToken()
    const headers = { "X-Requested-With": "XMLHttpRequest" }
    if (csrfToken) {
      headers["X-CSRF-Token"] = csrfToken
    }

    state.inFlight = true
    state.needsSync = false

    fetch(requestUrl, {
      method: requestMethod,
      credentials: "same-origin",
      headers
    })
      .then(response => {
        if (!response.ok) throw new Error(`Follow toggle failed: ${response.status}`)
        state.confirmed = targetState
      })
      .catch(() => {
        if (state.desired === targetState) {
          state.desired = state.confirmed
          this.setFollowState(form, state.confirmed)
        }
      })
      .finally(() => {
        state.inFlight = false
        if (state.needsSync || state.confirmed !== state.desired) {
          this.syncFollowState(form)
        }
      })
  }

  setFollowState(form, isFollowing) {
    const followUrl = form.dataset.followUrl || form.getAttribute("action")
    const unfollowUrl = form.dataset.unfollowUrl || form.getAttribute("action")
    const button = form.querySelector(".support-btn")
    const methodInput = form.querySelector("input[name=\"_method\"]")

    if (isFollowing) {
      form.dataset.following = "true"
      form.setAttribute("action", unfollowUrl)
      if (methodInput) {
        methodInput.value = "delete"
      } else {
        const hidden = document.createElement("input")
        hidden.type = "hidden"
        hidden.name = "_method"
        hidden.value = "delete"
        form.appendChild(hidden)
      }
      if (button) {
        button.classList.add("active")
        button.textContent = "\u2713 Supported"
      }
    } else {
      form.dataset.following = "false"
      form.setAttribute("action", followUrl)
      if (methodInput) methodInput.remove()
      if (button) {
        button.classList.remove("active")
        button.textContent = "+ Support"
      }
    }
  }

  getCsrfToken() {
    return document.querySelector("meta[name=\"csrf-token\"]")?.content || ""
  }
}
