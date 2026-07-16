const MOBILE_BREAKPOINT = 900
const SCRAMBLE_TICK_MS = 28
const STAGGER_MIN_MS = 35
const STAGGER_MAX_MS = 55
const SPRING_STIFFNESS = 170
const SPRING_DAMPING = 9
const SPRING_ENERGY_EPSILON = 0.02
const WHIP_GLITCH_SPEED_THRESHOLD = 260
const WHIP_GLITCH_MIN_MS = 80
const WHIP_GLITCH_MAX_MS = 120
const CURSOR_HOLD_MS = 500
const SUBLINE_TYPE_MS = 22

function prefersReducedMotion() {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches
}

function isMobileMode() {
  return window.innerWidth < MOBILE_BREAKPOINT || window.matchMedia("(pointer: coarse)").matches
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value))
}

function randomBinary() {
  return Math.random() < 0.5 ? "0" : "1"
}

function splitHeadlineIntoLetters(headline) {
  const lines = Array.from(headline.querySelectorAll(".headline-line"))
  const fullTextParts = []
  const letters = []

  lines.forEach((line) => {
    const text = line.textContent
    fullTextParts.push(text)
    line.textContent = ""

    text.split(" ").forEach((word, index, words) => {
      const wordSpan = document.createElement("span")
      wordSpan.className = "word"

      Array.from(word).forEach((char) => {
        const letterSpan = document.createElement("span")
        letterSpan.className = "letter is-scrambled"
        letterSpan.setAttribute("aria-hidden", "true")
        letterSpan.textContent = randomBinary()
        wordSpan.appendChild(letterSpan)
        letters.push({
          el: letterSpan,
          char,
          x: 0,
          y: 0,
          vx: 0,
          vy: 0,
          targetX: 0,
          targetY: 0,
          glitching: false,
        })
      })

      line.appendChild(wordSpan)

      if (index < words.length - 1) {
        const spaceSpan = document.createElement("span")
        spaceSpan.className = "letter-space"
        spaceSpan.setAttribute("aria-hidden", "true")
        spaceSpan.textContent = " "
        line.appendChild(spaceSpan)
      }
    })
  })

  headline.setAttribute("aria-label", fullTextParts.join(" "))
  return letters
}

function runScrambleReveal(letters, onComplete) {
  let cursor = 0
  letters.forEach((letter) => {
    cursor += STAGGER_MIN_MS + Math.random() * (STAGGER_MAX_MS - STAGGER_MIN_MS)
    letter.resolveAt = cursor
  })
  const totalDuration = cursor
  const start = performance.now()

  const scrambleTimer = setInterval(() => {
    const elapsed = performance.now() - start
    letters.forEach((letter) => {
      if (elapsed < letter.resolveAt) {
        letter.el.textContent = randomBinary()
      }
    })
  }, SCRAMBLE_TICK_MS)

  letters.forEach((letter) => {
    setTimeout(() => {
      letter.el.textContent = letter.char
      letter.el.classList.remove("is-scrambled")
      letter.el.classList.add("is-resolved")
    }, letter.resolveAt)
  })

  setTimeout(() => {
    clearInterval(scrambleTimer)
    onComplete()
  }, totalDuration + SCRAMBLE_TICK_MS)
}

function initScrollScramble(headline, letters) {
  let visible = true
  let scrambleTimer = null
  let pendingTimeouts = []

  function clearPending() {
    pendingTimeouts.forEach(clearTimeout)
    pendingTimeouts = []
  }

  function ensureTicking() {
    if (scrambleTimer) return
    scrambleTimer = setInterval(() => {
      letters.forEach((letter) => {
        if (letter.el.classList.contains("is-scrambled")) {
          letter.el.textContent = randomBinary()
        }
      })
    }, SCRAMBLE_TICK_MS)
  }

  function startScrambling() {
    clearPending()
    ensureTicking()

    let cursor = 0
    letters.forEach((letter) => {
      cursor += STAGGER_MIN_MS + Math.random() * (STAGGER_MAX_MS - STAGGER_MIN_MS)
      pendingTimeouts.push(
        setTimeout(() => {
          letter.el.classList.remove("is-resolved")
          letter.el.classList.add("is-scrambled")
        }, cursor),
      )
    })
  }

  function stopScrambling() {
    clearPending()

    let cursor = 0
    letters.forEach((letter) => {
      cursor += STAGGER_MIN_MS + Math.random() * (STAGGER_MAX_MS - STAGGER_MIN_MS)
      pendingTimeouts.push(
        setTimeout(() => {
          letter.el.textContent = letter.char
          letter.el.classList.remove("is-scrambled")
          letter.el.classList.add("is-resolved")
        }, cursor),
      )
    })

    pendingTimeouts.push(
      setTimeout(() => {
        if (scrambleTimer) {
          clearInterval(scrambleTimer)
          scrambleTimer = null
        }
      }, cursor + SCRAMBLE_TICK_MS),
    )
  }

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting && !visible) {
          visible = true
          stopScrambling()
        } else if (!entry.isIntersecting && visible) {
          visible = false
          startScrambling()
        }
      })
    },
    { rootMargin: "-15% 0px 0px 0px", threshold: 0 },
  )

  observer.observe(headline)
}

function triggerWhipGlitch(letter) {
  letter.glitching = true
  const trueChar = letter.char
  letter.el.textContent = randomBinary()
  letter.el.classList.add("is-glitching")

  const duration = WHIP_GLITCH_MIN_MS + Math.random() * (WHIP_GLITCH_MAX_MS - WHIP_GLITCH_MIN_MS)
  setTimeout(() => {
    letter.el.textContent = trueChar
    letter.el.classList.remove("is-glitching")
    letter.glitching = false
  }, duration)
}

function initPhysics(headline, letters, mobileMode) {
  let dragging = false
  let running = false
  let lastTime = performance.now()
  let lastScrollY = window.scrollY
  let pointerX = 0
  let pointerY = 0
  let capturedPointerId = null

  function step(now) {
    const dt = Math.min((now - lastTime) / 1000, 0.05)
    lastTime = now
    let totalEnergy = 0

    letters.forEach((letter) => {
      const ax = -SPRING_STIFFNESS * (letter.x - letter.targetX) - SPRING_DAMPING * letter.vx
      const ay = -SPRING_STIFFNESS * (letter.y - letter.targetY) - SPRING_DAMPING * letter.vy
      letter.vx += ax * dt
      letter.vy += ay * dt
      letter.x += letter.vx * dt
      letter.y += letter.vy * dt
      totalEnergy += letter.vx * letter.vx + letter.vy * letter.vy

      if (!letter.glitching && Math.hypot(letter.vx, letter.vy) > WHIP_GLITCH_SPEED_THRESHOLD) {
        triggerWhipGlitch(letter)
      }

      letter.el.style.transform = `translate(${letter.x.toFixed(2)}px, ${letter.y.toFixed(2)}px)`
    })

    if (totalEnergy < SPRING_ENERGY_EPSILON && !dragging) {
      running = false
      return
    }
    requestAnimationFrame(step)
  }

  function wake() {
    if (!running) {
      running = true
      lastTime = performance.now()
      requestAnimationFrame(step)
    }
  }

  const endDrag = () => {
    if (!dragging) return
    dragging = false
    if (capturedPointerId !== null) {
      try {
        headline.releasePointerCapture(capturedPointerId)
      } catch (e) {
        // already released by the browser — nothing to do
      }
      capturedPointerId = null
    }
    letters.forEach((letter) => {
      letter.targetX = 0
      letter.targetY = 0
    })
    wake()
  }

  if (!mobileMode) {
    window.addEventListener(
      "scroll",
      () => {
        const currentScrollY = window.scrollY
        const delta = currentScrollY - lastScrollY
        lastScrollY = currentScrollY
        if (delta === 0) return

        const impulse = clamp(delta * 0.6, -14, 14)
        letters.forEach((letter) => {
          letter.vy += impulse * (0.85 + 0.3 * Math.random())
        })
        wake()
      },
      { passive: true },
    )

    headline.addEventListener("pointerdown", (event) => {
      dragging = true
      pointerX = event.clientX
      pointerY = event.clientY
      capturedPointerId = event.pointerId

      letters.forEach((letter) => {
        const rect = letter.el.getBoundingClientRect()
        const restX = rect.left + rect.width / 2 - letter.x
        const restY = rect.top + rect.height / 2 - letter.y
        const dist = Math.hypot(restX - pointerX, restY - pointerY)
        letter.dragFalloff = Math.max(0.15, 1 - dist / 400)
      })

      try {
        headline.setPointerCapture(event.pointerId)
      } catch (e) {
        // no active pointer to capture (e.g. a synthetically dispatched event) — safe to ignore
      }
      wake()
    })

    headline.addEventListener("pointermove", (event) => {
      if (!dragging) return
      const dx = event.clientX - pointerX
      const dy = event.clientY - pointerY
      letters.forEach((letter) => {
        letter.targetX = dx * letter.dragFalloff
        letter.targetY = dy * letter.dragFalloff
      })
    })

    headline.addEventListener("pointerup", endDrag)
    headline.addEventListener("pointercancel", endDrag)
    headline.addEventListener("lostpointercapture", endDrag)
    window.addEventListener("pointerup", endDrag)
    window.addEventListener("blur", endDrag)
    document.addEventListener("visibilitychange", () => {
      if (document.hidden) endDrag()
    })
  } else {
    headline.addEventListener("pointerup", (event) => {
      letters.forEach((letter) => {
        const rect = letter.el.getBoundingClientRect()
        const cx = rect.left + rect.width / 2
        const cy = rect.top + rect.height / 2
        const dist = Math.hypot(cx - event.clientX, cy - event.clientY)
        const falloff = Math.max(0, 1 - dist / 200)
        const impulse = 11 * falloff
        const angle = Math.atan2(cy - event.clientY, cx - event.clientX)
        letter.vx += Math.cos(angle) * impulse
        letter.vy += Math.sin(angle) * impulse
      })
      wake()
    })
  }
}

function initParallax(hero) {
  if (window.innerWidth < MOBILE_BREAKPOINT) return

  const layers = Array.from(hero.querySelectorAll("[data-parallax]"))
  if (layers.length === 0) return

  let ticking = false
  function update() {
    const scrollY = window.scrollY
    layers.forEach((layer) => {
      const factor = parseFloat(layer.dataset.parallax)
      layer.style.transform = `translateY(${scrollY * factor}px)`
    })
    ticking = false
  }

  window.addEventListener(
    "scroll",
    () => {
      if (!ticking) {
        ticking = true
        requestAnimationFrame(update)
      }
    },
    { passive: true },
  )
}

function initReveal() {
  const targets = document.querySelectorAll(".reveal")
  if (targets.length === 0) return

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible")
          observer.unobserve(entry.target)
        }
      })
    },
    { threshold: 0.15 },
  )

  targets.forEach((target) => observer.observe(target))
}

function initScrollspy() {
  const sections = ["hero", "about", "projects", "resume"]
    .map((id) => document.getElementById(id))
    .filter(Boolean)
  if (sections.length === 0) return

  const setActive = (id) => {
    document.querySelectorAll("[data-scroll-link]").forEach((link) => {
      link.classList.toggle("is-active", link.dataset.scrollLink === id)
    })
  }

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          setActive(entry.target.id)
        }
      })
    },
    { rootMargin: "-40% 0px -55% 0px" },
  )

  sections.forEach((section) => observer.observe(section))
}

function setupSubline(hero) {
  const content = hero.querySelector("[data-subline-content]")
  if (!content) return null

  const chatLink = content.querySelector("[data-subline-chat]")
  const prefixText = chatLink
    ? chatLink.previousSibling
      ? chatLink.previousSibling.textContent
      : ""
    : content.textContent
  const suffixText = chatLink && chatLink.nextSibling ? chatLink.nextSibling.textContent : ""

  return { content, chatLink, prefixText, suffixText }
}

function hideSubline(subline) {
  if (!subline) return
  if (subline.chatLink) subline.chatLink.remove()
  subline.content.textContent = ""
}

function revealSublineContainer(subline) {
  if (!subline) return
  const container = subline.content.closest(".hero-subline")
  if (container) container.style.visibility = ""
}

function typeInto(container, text, cursor, onDone) {
  let i = 0
  function step() {
    if (i >= text.length) {
      onDone()
      return
    }
    container.insertBefore(document.createTextNode(text[i]), cursor)
    i += 1
    setTimeout(step, SUBLINE_TYPE_MS)
  }
  step()
}

function createCursor(extraClass) {
  const cursor = document.createElement("span")
  cursor.className = extraClass ? `hero-cursor ${extraClass}` : "hero-cursor"
  cursor.setAttribute("aria-hidden", "true")
  cursor.textContent = "█"
  return cursor
}

function runCursorSequence(headline, subline) {
  if (!subline) return
  const { content, chatLink, prefixText, suffixText } = subline
  const cursor = createCursor()

  const lastLine = headline.querySelector(".headline-line:last-child")
  lastLine.appendChild(cursor)

  setTimeout(() => {
    content.appendChild(cursor)
    typeInto(content, prefixText, cursor, () => {
      if (chatLink) {
        const chatTypeDuration = chatLink.textContent.length * SUBLINE_TYPE_MS
        setTimeout(() => {
          content.insertBefore(chatLink, cursor)
          typeInto(content, suffixText, cursor, () => {})
        }, chatTypeDuration)
      } else {
        typeInto(content, suffixText, cursor, () => {})
      }
    })
  }, CURSOR_HOLD_MS)
}

function showStaticCursor(subline) {
  if (!subline) return
  subline.content.appendChild(createCursor("is-static"))
}

const KONAMI = [
  "ArrowUp",
  "ArrowUp",
  "ArrowDown",
  "ArrowDown",
  "ArrowLeft",
  "ArrowRight",
  "ArrowLeft",
  "ArrowRight",
  "b",
  "a",
]

function revealSecret(innerHtml) {
  if (document.querySelector(".konami-toast")) return

  if (!prefersReducedMotion()) {
    const crt = document.createElement("div")
    crt.className = "konami-crt"
    crt.setAttribute("aria-hidden", "true")
    document.body.appendChild(crt)
    setTimeout(() => crt.remove(), 1300)
  }

  const toast = document.createElement("div")
  toast.className = "konami-toast"
  toast.setAttribute("role", "status")
  toast.innerHTML = innerHtml
  document.body.appendChild(toast)
  requestAnimationFrame(() => toast.classList.add("is-visible"))

  setTimeout(() => {
    toast.classList.remove("is-visible")
    setTimeout(() => toast.remove(), 400)
  }, 6000)
}

function triggerKonami() {
  revealSecret(
    '<span aria-hidden="true">▲▲▼▼◄►◄►BA</span> <strong>SECRET UNLOCKED</strong>' +
      '<span class="konami-body">You found the dev console. ' +
      '<a href="/docs/colophon">See how this site is built →</a></span>',
  )
}

const GRID_CELL_PX = 40
const GRID_SPAWN_MS = 750
const GRID_CELL_LIFE_MS = 2600
const GRID_MAX_CELLS = 6
const GRID_SECRET_SCORE = 15
const GRID_TEXT_PAD = 20

function initHeroGrid(hero) {
  if (prefersReducedMotion() || isMobileMode()) return

  const layer = document.createElement("div")
  layer.className = "hero-grid-cells"
  layer.setAttribute("aria-hidden", "true")
  hero.appendChild(layer)

  const scoreEl = document.createElement("div")
  scoreEl.className = "hero-score"
  scoreEl.hidden = true
  hero.appendChild(scoreEl)

  let score = parseInt(localStorage.getItem("dg-grid-score") || "0", 10)
  if (Number.isNaN(score)) score = 0
  let secretShown = score >= GRID_SECRET_SCORE

  function renderScore() {
    if (score > 0) {
      scoreEl.hidden = false
      scoreEl.textContent = `SCORE ${String(score).padStart(3, "0")}`
    }
  }
  renderScore()

  // Rectangles (hero-relative) covering the hero text, so cells never spawn behind it.
  function textZones() {
    const heroRect = hero.getBoundingClientRect()
    return Array.from(hero.querySelectorAll(".hero-headline, .hero-subline")).map((el) => {
      const r = el.getBoundingClientRect()
      return {
        left: r.left - heroRect.left - GRID_TEXT_PAD,
        top: r.top - heroRect.top - GRID_TEXT_PAD,
        right: r.right - heroRect.left + GRID_TEXT_PAD,
        bottom: r.bottom - heroRect.top + GRID_TEXT_PAD,
      }
    })
  }

  function overlapsText(x, y, zones) {
    return zones.some(
      (z) => x < z.right && x + GRID_CELL_PX > z.left && y < z.bottom && y + GRID_CELL_PX > z.top,
    )
  }

  function spawn() {
    if (layer.childElementCount >= GRID_MAX_CELLS) return
    const cols = Math.floor(hero.clientWidth / GRID_CELL_PX)
    const rows = Math.floor(hero.clientHeight / GRID_CELL_PX)
    if (cols < 3 || rows < 3) return

    const zones = textZones()
    let x
    let y
    let tries = 0
    do {
      x = Math.floor(Math.random() * cols) * GRID_CELL_PX
      y = Math.floor(Math.random() * rows) * GRID_CELL_PX
      tries += 1
    } while (overlapsText(x, y, zones) && tries < 12)
    if (overlapsText(x, y, zones)) return

    const cell = document.createElement("button")
    cell.type = "button"
    cell.className = "grid-cell"
    cell.tabIndex = -1
    cell.setAttribute("aria-hidden", "true")
    cell.textContent = randomBinary()
    cell.style.left = `${x}px`
    cell.style.top = `${y}px`

    const fadeOut = () => {
      cell.classList.add("is-fading")
      setTimeout(() => cell.remove(), 250)
    }
    const life = setTimeout(fadeOut, GRID_CELL_LIFE_MS)

    cell.addEventListener("pointerdown", (event) => {
      event.preventDefault()
      clearTimeout(life)
      cell.classList.add("is-hit")
      setTimeout(() => cell.remove(), 200)

      score += 1
      try {
        localStorage.setItem("dg-grid-score", String(score))
      } catch (e) {
        // storage unavailable (private mode) — score just won't persist
      }
      renderScore()

      if (!secretShown && score >= GRID_SECRET_SCORE) {
        secretShown = true
        revealSecret(
          '<strong>GRID CRACKED</strong>' +
            '<span class="konami-body">Fastest fingers in Tier III. ' +
            '<a href="/docs">Reward: dig into DylanDocs →</a></span>',
        )
      }
    })

    layer.appendChild(cell)
  }

  let timer = null
  let inView = false

  function sync() {
    if (inView && !document.hidden) {
      if (!timer) timer = setInterval(spawn, GRID_SPAWN_MS)
    } else if (timer) {
      clearInterval(timer)
      timer = null
      layer.replaceChildren()
    }
  }

  new IntersectionObserver(
    (entries) => {
      inView = entries[0].isIntersecting
      sync()
    },
    { threshold: 0.1 },
  ).observe(hero)

  document.addEventListener("visibilitychange", sync)
}

function initKonami() {
  let pos = 0
  window.addEventListener("keydown", (event) => {
    const key = event.key.length === 1 ? event.key.toLowerCase() : event.key
    if (key === KONAMI[pos]) {
      pos += 1
      if (pos === KONAMI.length) {
        pos = 0
        triggerKonami()
      }
    } else {
      pos = key === KONAMI[0] ? 1 : 0
    }
  })
}

function initHero() {
  const hero = document.getElementById("hero")
  if (!hero) return

  const headline = hero.querySelector(".hero-headline")
  const reducedMotion = prefersReducedMotion()
  const letters = splitHeadlineIntoLetters(headline)
  const subline = setupSubline(hero)

  if (reducedMotion) {
    letters.forEach((letter) => {
      letter.el.textContent = letter.char
      letter.el.classList.remove("is-scrambled")
      letter.el.classList.add("is-resolved")
    })
    showStaticCursor(subline)
  } else {
    hideSubline(subline)
    runScrambleReveal(letters, () => {
      initPhysics(headline, letters, isMobileMode())
      runCursorSequence(headline, subline)
      initScrollScramble(headline, letters)
    })
    initParallax(hero)
    initHeroGrid(hero)
  }

  revealSublineContainer(subline)
  initReveal()
  initScrollspy()
}

document.addEventListener("DOMContentLoaded", () => {
  initHero()
  initKonami()
})
