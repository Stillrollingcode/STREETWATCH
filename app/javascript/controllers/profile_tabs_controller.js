import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.handleClick = this.handleClick.bind(this)
    this.element.addEventListener("click", this.handleClick)
  }

  disconnect() {
    this.element.removeEventListener("click", this.handleClick)
  }

  handleClick(event) {
    const claimBtn = event.target.closest("#claim-btn")
    if (claimBtn) {
      event.preventDefault()
      this.toggleClaimInfo()
      return
    }

    const subTab = event.target.closest(".content-sub-tab")
    if (subTab) {
      event.preventDefault()
      this.switchSubTab(subTab)
      return
    }

    const tab = event.target.closest(".content-tab")
    if (tab) {
      event.preventDefault()
      this.switchTab(tab)
    }
  }

  switchTab(tab) {
    const tabs = this.element.querySelectorAll(".content-tab")
    const sections = this.element.querySelectorAll(".content-section")
    const targetTab = tab.dataset.tab
    const targetSection = this.element.querySelector(`#${targetTab}-section`)

    if (!targetSection) {
      return
    }

    tabs.forEach(t => t.classList.remove("active"))
    sections.forEach(s => s.classList.remove("active"))

    tab.classList.add("active")
    targetSection.classList.add("active")
  }

  switchSubTab(subTab) {
    const targetSubTab = subTab.dataset.subtab
    const parentSection = subTab.closest(".content-section")
    if (!parentSection) {
      return
    }

    const parentSubTabs = parentSection.querySelectorAll(".content-sub-tab")
    const parentSubSections = parentSection.querySelectorAll(".content-sub-section")
    const targetSection = parentSection.querySelector(`#${targetSubTab}-section`)

    if (!targetSection) {
      return
    }

    parentSubTabs.forEach(t => t.classList.remove("active"))
    parentSubSections.forEach(s => s.classList.remove("active"))

    subTab.classList.add("active")
    targetSection.classList.add("active")

    this.loadLazySection(targetSection)
  }

  loadLazySection(targetSection) {
    const lazyUrl = targetSection.dataset.lazyUrl
    if (!lazyUrl || targetSection.dataset.loaded) {
      return
    }

    fetch(lazyUrl, { headers: { "X-Requested-With": "XMLHttpRequest" } })
      .then(response => response.text())
      .then(html => {
        targetSection.innerHTML = html
        targetSection.dataset.loaded = "true"
      })
      .catch(err => {
        console.error("[Lazy Load] Error loading sub-tab:", err)
        targetSection.innerHTML = '<div class="empty-state">Error loading content. Please try again.</div>'
      })
  }

  toggleClaimInfo() {
    const claimBanner = this.element.querySelector("#claim-banner")
    const claimInfoBanner = this.element.querySelector("#claim-info-banner")

    if (claimBanner && claimInfoBanner) {
      claimBanner.style.display = "none"
      claimInfoBanner.style.display = "block"
    }
  }
}
