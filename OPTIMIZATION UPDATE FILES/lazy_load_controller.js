// app/javascript/controllers/lazy_load_controller.js
// Stimulus controller for lazy loading content and infinite scroll

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "loader", "loadMore"]
  static values = { 
    url: String,
    page: Number,
    loading: Boolean,
    hasMore: Boolean,
    offset: Number,
    limit: Number
  }
  
  connect() {
    console.log("Lazy load controller connected")
    
    // Initialize values
    this.pageValue = this.pageValue || 1
    this.offsetValue = this.offsetValue || 0
    this.limitValue = this.limitValue || 24
    this.loadingValue = false
    this.hasMoreValue = this.hasMoreValue !== false
    
    // Set up intersection observer for infinite scroll
    this.setupIntersectionObserver()
    
    // Load initial content if needed
    if (this.data.get("autoload") === "true") {
      this.loadContent()
    }
  }
  
  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }
  
  setupIntersectionObserver() {
    // Use IntersectionObserver for infinite scroll
    const options = {
      root: null,
      rootMargin: '100px', // Start loading 100px before reaching the bottom
      threshold: 0.1
    }
    
    this.observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting && !this.loadingValue && this.hasMoreValue) {
          this.loadMore()
        }
      })
    }, options)
    
    // Observe the loader element if it exists
    if (this.hasLoaderTarget) {
      this.observer.observe(this.loaderTarget)
    }
  }
  
  async loadContent() {
    if (this.loadingValue || !this.hasMoreValue) return
    
    this.loadingValue = true
    this.showLoader()
    
    try {
      const url = this.buildUrl()
      const response = await fetch(url, {
        headers: {
          'Accept': 'text/html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (!response.ok) throw new Error('Network response was not ok')
      
      const html = await response.text()
      
      // Check if we got content
      if (html.trim()) {
        this.appendContent(html)
        this.incrementPage()
      } else {
        this.hasMoreValue = false
        this.hideLoadMoreButton()
      }
    } catch (error) {
      console.error('Error loading content:', error)
      this.showError()
    } finally {
      this.loadingValue = false
      this.hideLoader()
    }
  }
  
  loadMore() {
    this.loadContent()
  }
  
  buildUrl() {
    const url = new URL(this.urlValue, window.location.origin)
    
    // Add pagination parameters
    if (this.data.get("pagination-type") === "offset") {
      url.searchParams.set('offset', this.offsetValue)
      url.searchParams.set('limit', this.limitValue)
    } else {
      url.searchParams.set('page', this.pageValue)
    }
    
    // Preserve existing filters
    const currentParams = new URLSearchParams(window.location.search)
    currentParams.forEach((value, key) => {
      if (!['page', 'offset', 'limit'].includes(key)) {
        url.searchParams.set(key, value)
      }
    })
    
    return url.toString()
  }
  
  appendContent(html) {
    // Create a temporary container to parse the HTML
    const temp = document.createElement('div')
    temp.innerHTML = html
    
    // Move all children to the container
    while (temp.firstChild) {
      this.containerTarget.appendChild(temp.firstChild)
    }
    
    // Dispatch event for other components that might need to initialize
    this.dispatch('content-loaded', { 
      detail: { 
        page: this.pageValue,
        offset: this.offsetValue 
      } 
    })
  }
  
  incrementPage() {
    if (this.data.get("pagination-type") === "offset") {
      this.offsetValue += this.limitValue
    } else {
      this.pageValue += 1
    }
  }
  
  showLoader() {
    if (this.hasLoaderTarget) {
      this.loaderTarget.classList.remove('hidden')
    }
  }
  
  hideLoader() {
    if (this.hasLoaderTarget) {
      this.loaderTarget.classList.add('hidden')
    }
  }
  
  showError() {
    const errorMessage = document.createElement('div')
    errorMessage.className = 'alert alert-danger'
    errorMessage.textContent = 'Error loading content. Please try again.'
    this.containerTarget.appendChild(errorMessage)
    
    // Remove error after 5 seconds
    setTimeout(() => {
      errorMessage.remove()
    }, 5000)
  }
  
  hideLoadMoreButton() {
    if (this.hasLoadMoreTarget) {
      this.loadMoreTarget.style.display = 'none'
    }
  }
  
  // Manual trigger for "Load More" button
  loadMoreClick(event) {
    event.preventDefault()
    this.loadMore()
  }
  
  // Reset the pagination (useful for filters)
  reset() {
    this.pageValue = 1
    this.offsetValue = 0
    this.hasMoreValue = true
    this.containerTarget.innerHTML = ''
    this.loadContent()
  }
}
