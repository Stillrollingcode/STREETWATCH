import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.nextUrl = null
    this.autoplayEnabled = true
    this.ytPlayer = null
    this.vimeoPlayer = null
    this.navFetchTimer = null

    this.handleAutoplayToggle = this.handleAutoplayToggle.bind(this)
    this.handleViewModeClick = this.handleViewModeClick.bind(this)
    this.handleWrapperClick = this.handleWrapperClick.bind(this)

    this.readAutoplaySetting()
    this.updateAutoplayUI()
    this.loadFilmNavigation()
    this.initViewMode()
    this.tryEnterFullscreen()
    this.setupClickToPause()
  }

  disconnect() {
    if (this.navFetchTimer) {
      clearTimeout(this.navFetchTimer)
    }

    const autoplayToggle = this.element.querySelector("#autoplay-toggle")
    if (autoplayToggle) {
      autoplayToggle.removeEventListener("click", this.handleAutoplayToggle)
    }

    this.element.querySelectorAll(".view-mode-btn").forEach(btn => {
      btn.removeEventListener("click", this.handleViewModeClick)
    })

    const wrapper = this.element.querySelector(".video-player-wrapper")
    if (wrapper) {
      wrapper.removeEventListener("click", this.handleWrapperClick)
    }
  }

  readAutoplaySetting() {
    const stored = localStorage.getItem("filmAutoplay")
    if (stored === null) {
      this.autoplayEnabled = true
      localStorage.setItem("filmAutoplay", "true")
    } else {
      this.autoplayEnabled = stored === "true"
    }
  }

  updateAutoplayUI() {
    const toggle = this.element.querySelector("#autoplay-toggle")
    if (toggle) {
      toggle.classList.toggle("active", this.autoplayEnabled)
    }
  }

  isFullscreen() {
    return !!(document.fullscreenElement || document.webkitFullscreenElement ||
      document.mozFullScreenElement || document.msFullscreenElement)
  }

  goToNextFilm() {
    if (this.nextUrl && this.autoplayEnabled) {
      if (this.isFullscreen()) {
        sessionStorage.setItem("filmAutoplayFullscreen", "true")
      }
      window.location.href = this.nextUrl
    }
  }

  tryEnterFullscreen() {
    if (sessionStorage.getItem("filmAutoplayFullscreen") !== "true") return
    sessionStorage.removeItem("filmAutoplayFullscreen")

    const videoWrapper = this.element.querySelector(".video-player-wrapper")
    const videoJsPlayer = this.element.querySelector("#film-video-player")

    let fullscreenAttempted = false

    if (videoJsPlayer && typeof videojs !== "undefined") {
      const player = videojs.getPlayer("film-video-player")
      if (player) {
        setTimeout(() => {
          player.requestFullscreen().catch(() => {
            this.setViewMode("theater")
          })
        }, 500)
        fullscreenAttempted = true
      }
    } else if (videoWrapper) {
      setTimeout(() => {
        const requestFs = videoWrapper.requestFullscreen || videoWrapper.webkitRequestFullscreen ||
          videoWrapper.mozRequestFullScreen || videoWrapper.msRequestFullscreen
        if (requestFs) {
          requestFs.call(videoWrapper).catch(() => {
            this.setViewMode("theater")
          })
        } else {
          this.setViewMode("theater")
        }
      }, 500)
      fullscreenAttempted = true
    }

    if (!fullscreenAttempted) {
      this.setViewMode("theater")
    }
  }

  getViewMode() {
    return localStorage.getItem("filmViewMode") || "default"
  }

  setViewMode(mode) {
    document.body.classList.remove("view-mode-default", "view-mode-theater", "view-mode-split")
    document.body.classList.add(`view-mode-${mode}`)
    localStorage.setItem("filmViewMode", mode)
    this.updateViewModeButtons(mode)
    this.moveBottomActions(mode)
  }

  moveBottomActions(mode) {
    const bottomActions = this.element.querySelector(".film-bottom-actions")
    const videoWrapper = this.element.querySelector(".video-player-wrapper")
    const filmShell = this.element

    if (!bottomActions || !videoWrapper || !filmShell) return

    if (mode === "split") {
      videoWrapper.appendChild(bottomActions)
    } else {
      filmShell.appendChild(bottomActions)
    }
  }

  updateViewModeButtons(mode) {
    this.element.querySelectorAll(".view-mode-btn").forEach(btn => {
      btn.classList.toggle("active", btn.dataset.mode === mode)
    })
  }

  initViewMode() {
    let savedMode = this.getViewMode()

    const isMobile = window.innerWidth <= 600
    const isTablet = window.innerWidth <= 1024

    if (isMobile) {
      savedMode = "default"
    } else if (isTablet && savedMode === "split") {
      savedMode = "theater"
    }

    this.setViewMode(savedMode)

    this.element.querySelectorAll(".view-mode-btn").forEach(btn => {
      btn.addEventListener("click", this.handleViewModeClick)
    })
  }

  handleViewModeClick(event) {
    const mode = event.currentTarget.dataset.mode
    if (mode) {
      this.setViewMode(mode)
    }
  }

  setupYouTubePlayer() {
    const iframe = this.element.querySelector("#youtube-player")
    if (!iframe || typeof YT === "undefined") return

    this.ytPlayer = new YT.Player("youtube-player", {
      events: {
        onStateChange: event => {
          if (event.data === 0) {
            this.goToNextFilm()
          }
        }
      }
    })
  }

  setupVimeoPlayer() {
    const iframe = this.element.querySelector("#vimeo-player")
    if (!iframe || typeof Vimeo === "undefined") return

    this.vimeoPlayer = new Vimeo.Player(iframe)
    this.vimeoPlayer.on("ended", () => {
      this.goToNextFilm()
    })
  }

  setupVideoJsPlayer() {
    const videoElement = this.element.querySelector("#film-video-player")
    if (!videoElement || typeof videojs === "undefined") return

    const player = videojs.getPlayer("film-video-player")
    if (player) {
      player.on("ended", () => {
        this.goToNextFilm()
      })
    }
  }

  togglePlayPause() {
    if (this.ytPlayer && typeof this.ytPlayer.getPlayerState === "function") {
      const state = this.ytPlayer.getPlayerState()
      if (state === YT.PlayerState.PLAYING) {
        this.ytPlayer.pauseVideo()
      } else {
        this.ytPlayer.playVideo()
      }
      return
    }

    if (this.vimeoPlayer) {
      this.vimeoPlayer.getPaused().then(paused => {
        if (paused) {
          this.vimeoPlayer.play()
        } else {
          this.vimeoPlayer.pause()
        }
      })
      return
    }

    const player = typeof videojs !== "undefined" ? videojs.getPlayer("film-video-player") : null
    if (player) {
      if (player.paused()) {
        player.play()
      } else {
        player.pause()
      }
    }
  }

  setupClickToPause() {
    const wrapper = this.element.querySelector(".video-player-wrapper")
    if (!wrapper) return

    wrapper.addEventListener("click", this.handleWrapperClick)
  }

  handleWrapperClick(event) {
    if (event.target.closest(".film-nav-bar") ||
      event.target.closest(".film-bottom-actions") ||
      event.target.closest("button") ||
      event.target.closest("a")) {
      return
    }
    this.togglePlayPause()
  }

  loadFilmNavigation() {
    const navBar = this.element.querySelector(".film-nav-bar")
    if (!navBar || navBar.dataset.loaded) return
    navBar.dataset.loaded = "true"

    const autoplayToggle = this.element.querySelector("#autoplay-toggle")
    if (autoplayToggle) {
      autoplayToggle.addEventListener("click", this.handleAutoplayToggle)
    }

    this.navFetchTimer = setTimeout(() => {
      const filmId = navBar.dataset.filmId
      const params = new URLSearchParams()
      if (navBar.dataset.navContext) params.set("nav_context", navBar.dataset.navContext)
      if (navBar.dataset.navId) params.set("nav_id", navBar.dataset.navId)
      if (navBar.dataset.navSort) params.set("nav_sort", navBar.dataset.navSort)
      if (navBar.dataset.navType) params.set("nav_type", navBar.dataset.navType)

      fetch(`/films/${filmId}/navigation?${params.toString()}`)
        .then(r => r.json())
        .then(data => {
          const prevBtn = navBar.querySelector(".prev-btn")
          const nextBtn = navBar.querySelector(".next-btn")

          const buildUrl = id => {
            const url = new URL(`/films/${id}`, window.location.origin)
            url.searchParams.set("nav_context", data.context)
            if (data.context !== "random") {
              if (navBar.dataset.navId) url.searchParams.set("nav_id", navBar.dataset.navId)
              if (navBar.dataset.navSort) url.searchParams.set("nav_sort", navBar.dataset.navSort)
              if (navBar.dataset.navType) url.searchParams.set("nav_type", navBar.dataset.navType)
            }
            return url.toString()
          }

          if (data.prev_id && prevBtn) {
            prevBtn.href = buildUrl(data.prev_id)
            prevBtn.style.visibility = "visible"
          }
          if (data.next_id && nextBtn) {
            const url = buildUrl(data.next_id)
            nextBtn.href = url
            nextBtn.style.visibility = "visible"
            this.nextUrl = url
          }

          if (this.element.querySelector("#youtube-player")) {
            if (typeof YT === "undefined") {
              if (!document.querySelector("script[data-youtube-iframe-api]")) {
                const tag = document.createElement("script")
                tag.src = "https://www.youtube.com/iframe_api"
                tag.dataset.youtubeIframeApi = "true"
                document.head.appendChild(tag)
              }
              window.onYouTubeIframeAPIReady = () => this.setupYouTubePlayer()
            } else {
              this.setupYouTubePlayer()
            }
          } else if (this.element.querySelector("#vimeo-player")) {
            if (typeof Vimeo === "undefined") {
              if (!document.querySelector("script[data-vimeo-player-api]")) {
                const tag = document.createElement("script")
                tag.src = "https://player.vimeo.com/api/player.js"
                tag.dataset.vimeoPlayerApi = "true"
                tag.onload = () => this.setupVimeoPlayer()
                document.head.appendChild(tag)
              }
            } else {
              this.setupVimeoPlayer()
            }
          } else if (this.element.querySelector("#film-video-player")) {
            this.setupVideoJsPlayer()
          }
        })
        .catch(() => {})
    }, 1000)
  }

  handleAutoplayToggle() {
    this.autoplayEnabled = !this.autoplayEnabled
    localStorage.setItem("filmAutoplay", this.autoplayEnabled ? "true" : "false")
    this.updateAutoplayUI()
  }
}
