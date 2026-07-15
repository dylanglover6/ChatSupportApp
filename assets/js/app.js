import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let Hooks = {}

Hooks.AutoScroll = {
  mounted() {
    this.scrollToBottom()
  },
  updated() {
    this.scrollToBottom()
  },
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  }
}

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  hooks: Hooks,
  params: {_csrf_token: csrfToken}
})

liveSocket.connect()
window.liveSocket = liveSocket

function setActiveNav() {
  const path = window.location.pathname
  document.querySelectorAll("[data-nav-link]").forEach((link) => {
    const linkPath = new URL(link.href, window.location.origin).pathname
    const isActive = linkPath === "/" ? path === "/" : path.startsWith(linkPath)
    link.classList.toggle("is-active", isActive)
  })
}

function initMobileNav() {
  const toggle = document.querySelector("[data-nav-toggle]")
  const close = document.querySelector("[data-nav-close]")
  const overlay = document.querySelector("[data-nav-overlay]")
  if (!toggle || !overlay) return

  const closeMenu = () => {
    overlay.setAttribute("data-state", "closed")
    toggle.setAttribute("aria-expanded", "false")
  }
  const openMenu = () => {
    overlay.setAttribute("data-state", "open")
    toggle.setAttribute("aria-expanded", "true")
  }

  toggle.addEventListener("click", () => {
    overlay.getAttribute("data-state") === "open" ? closeMenu() : openMenu()
  })
  close?.addEventListener("click", closeMenu)
  overlay.querySelectorAll("a").forEach((link) => link.addEventListener("click", closeMenu))
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") closeMenu()
  })
}

document.addEventListener("DOMContentLoaded", () => {
  setActiveNav()
  initMobileNav()
})
window.addEventListener("phx:page-loading-stop", setActiveNav)
