import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import "./portfolio.js"

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

Hooks.WidgetPath = {
  mounted() {
    this.report()
    this.reportOnNavigate = () => this.report()
    window.addEventListener("phx:page-loading-stop", this.reportOnNavigate)

    // Open the widget in place when something outside it asks (e.g. the hero "Chat" link).
    this.openFromEvent = () => this.pushEvent("open")
    window.addEventListener("dylanbot:open", this.openFromEvent)

    // Remember once the visitor has opened DylanBot so the first-visit badge stops nagging.
    this.handleEvent("dylanbot_opened", () => {
      try { window.localStorage.setItem("dylanbot_greeted", "1") } catch (_) {}
    })
    let greeted = false
    try { greeted = window.localStorage.getItem("dylanbot_greeted") === "1" } catch (_) {}
    if (greeted) this.pushEvent("dismiss_greeting")
  },
  destroyed() {
    window.removeEventListener("phx:page-loading-stop", this.reportOnNavigate)
    window.removeEventListener("dylanbot:open", this.openFromEvent)
  },
  report() {
    this.pushEvent("path_changed", { path: window.location.pathname })
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

// Any element marked [data-open-widget] opens the DylanBot widget in place instead of
// navigating (the hero "Chat" link keeps its href as a no-JS fallback).
document.addEventListener("click", (e) => {
  const trigger = e.target.closest("[data-open-widget]")
  if (trigger) {
    e.preventDefault()
    window.dispatchEvent(new CustomEvent("dylanbot:open"))
  }
})

// Collapsible left nav. State lives on <html> (applied pre-paint by an inline script
// in the root layout) and persists in localStorage. Delegated so it survives LiveView
// navigations without re-binding.
function setNavCollapsed(collapsed) {
  document.documentElement.classList.toggle("nav-collapsed", collapsed)
  try {
    window.localStorage.setItem("dg-nav-collapsed", collapsed ? "1" : "0")
  } catch (e) {}
}

document.addEventListener("click", (e) => {
  if (e.target.closest("[data-nav-collapse]")) {
    e.preventDefault()
    setNavCollapsed(true)
  } else if (e.target.closest("[data-nav-expand]")) {
    e.preventDefault()
    setNavCollapsed(false)
  }
})

document.addEventListener("DOMContentLoaded", () => {
  setActiveNav()
  initMobileNav()
})
window.addEventListener("phx:page-loading-stop", setActiveNav)
