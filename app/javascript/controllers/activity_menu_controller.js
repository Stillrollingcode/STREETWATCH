import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, countsUrl: String }
  static targets = ["menu", "badge"]

  connect() {
    this.loaded = false
    this.countsLoaded = false
    this.handleDocumentClick = this.handleDocumentClick.bind(this)
    document.addEventListener("click", this.handleDocumentClick)
    this.loadCounts()
  }

  disconnect() {
    document.removeEventListener("click", this.handleDocumentClick)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    this.menuTarget.classList.toggle("open")

    if (this.menuTarget.classList.contains("open") && !this.loaded) {
      this.loadMenu()
    }
  }

  handleDocumentClick(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.remove("open")
    }
  }

  loadMenu() {
    if (!this.urlValue) {
      return
    }

    fetch(this.urlValue, { headers: { "X-Requested-With": "XMLHttpRequest" } })
      .then(response => response.text())
      .then(html => {
        this.menuTarget.innerHTML = html
        this.loaded = true
      })
      .catch(error => {
        console.error("Error loading activity menu:", error)
        this.menuTarget.innerHTML = '<div style="padding: 16px; color: var(--muted); font-size: 13px;">Unable to load activity.</div>'
      })
  }

  loadCounts() {
    if (this.countsLoaded || !this.countsUrlValue) {
      return
    }

    this.countsLoaded = true
    fetch(this.countsUrlValue, { headers: { "X-Requested-With": "XMLHttpRequest" } })
      .then(response => response.json())
      .then(data => {
        if (!this.hasBadgeTarget) {
          return
        }

        const total = parseInt(data.total_activity_count, 10) || 0
        if (total > 0) {
          this.badgeTarget.textContent = total
          this.badgeTarget.style.display = ""
        } else {
          this.badgeTarget.style.display = "none"
        }
      })
      .catch(error => {
        console.error("Error loading activity counts:", error)
        this.countsLoaded = false
      })
  }

  markRead(event) {
    event.preventDefault()
    const compactView = this.menuTarget.querySelector("#activity-content-compact")
    const expandedView = this.menuTarget.querySelector("#activity-content-expanded")
    if (!compactView) {
      return
    }

    const unreadItems = Array.from(this.menuTarget.querySelectorAll(".activity-item.unread"))
      .filter(item => item.querySelector(".activity-type-badge.notification"))
    const notificationItems = Array.from(compactView.querySelectorAll(".activity-item"))
      .filter(item => item.querySelector(".activity-type-badge.notification"))
    const notificationCount = unreadItems.length > 0 ? unreadItems.length : notificationItems.length

    if (notificationCount === 0) {
      return
    }

    const csrfToken = this.getCsrfToken()
    if (!csrfToken) {
      console.error("CSRF token not found")
      return
    }

    fetch("/notifications/mark_as_read", {
      method: "POST",
      headers: {
        "X-CSRF-Token": csrfToken,
        "Content-Type": "application/json"
      }
    })
      .then(response => {
        if (!response.ok) {
          throw new Error("Failed to mark as read")
        }

        notificationItems.forEach(item => item.remove())

        if (expandedView) {
          expandedView.querySelectorAll(".activity-item.unread").forEach(item => {
            item.classList.remove("unread")
          })
        }

        const markReadBtn = this.menuTarget.querySelector(".mark-read-btn")
        if (markReadBtn) {
          markReadBtn.remove()
        }

        if (this.hasBadgeTarget) {
          const currentCount = parseInt(this.badgeTarget.textContent, 10)
          const newCount = currentCount - notificationCount
          if (newCount > 0) {
            this.badgeTarget.textContent = newCount
          } else {
            this.badgeTarget.remove()
          }
        }

        const remainingCompactItems = compactView.querySelectorAll(".activity-item")
        if (remainingCompactItems.length === 0) {
          const existingEmpty = compactView.querySelector(".activity-empty")
          if (!existingEmpty) {
            const emptyState = document.createElement("div")
            emptyState.className = "activity-empty"
            emptyState.innerHTML = '<div style="font-size: 32px; margin-bottom: 8px; opacity: 0.3;">✓</div><div>No new activity</div>'
            const expandBtn = compactView.querySelector(".expand-notifications-btn")
            if (expandBtn) {
              compactView.insertBefore(emptyState, expandBtn)
            } else {
              compactView.appendChild(emptyState)
            }
          }
        }
      })
      .catch(error => {
        console.error("Error marking notifications as read:", error)
      })
  }

  toggleExpand(event) {
    event.preventDefault()
    const compactView = this.menuTarget.querySelector("#activity-content-compact")
    const expandedView = this.menuTarget.querySelector("#activity-content-expanded")
    if (!compactView || !expandedView) {
      return
    }

    if (compactView.style.display === "none") {
      compactView.style.display = "block"
      expandedView.style.display = "none"
    } else {
      compactView.style.display = "none"
      expandedView.style.display = "block"
    }
  }

  getCsrfToken() {
    const bodyToken = document.body?.getAttribute("data-csrf-token")
    if (bodyToken) {
      return bodyToken
    }

    const metaTag = document.head?.querySelector('meta[name="csrf-token"]')
    return metaTag ? metaTag.getAttribute("content") : null
  }
}
