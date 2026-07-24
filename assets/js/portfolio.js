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

// Arrow-key cheat code: the classic sequence minus the B/A button press.
const KONAMI = [
  "ArrowUp",
  "ArrowUp",
  "ArrowDown",
  "ArrowDown",
  "ArrowLeft",
  "ArrowRight",
  "ArrowLeft",
  "ArrowRight",
]

// ASCII portrait of Dylan (from the headshot) plus a stylized name banner, rendered as a
// flickering CRT overlay when the cheat code lands. Keep the whitespace/backslashes exactly
// as-is — they are the image; these strings are pre-escaped for JS.
const DYLAN_ASCII = "                     -@@@@@@@@#\n                   %@@@@@@@@@@@@@.\n                 +@@@@@@@@@@@@@@@@\n                 @@@@@@@=       @@@\n                .@@@@@@@@#   :-: @@\n                 @@@#@@@##@.-@=  @@\n                 #@@=@+  @@.     #-\n                 @@*=@* #@@%.\n                -@@@@@@@@@@@@@%  @+\n                 @@@@@@*@@:      @*\n                 @@@@@@@@@:     @@\n                  =#@@@@@@@@#-  @\n                   :@@@@@@@=   =.\n                 =@@@@@@*#.   %==#=+=-:\n             .-%@@@@@@@@@*  %@@.#@+**#@%%#=:\n..       .-+#@@@@@@@@@@@@@::@@@+@%+++*@%%#%@%+:\n....  .-#*#@@+%@*@@@@@@@@@@=@@%@@#*=***@*#*@@*@.\n:::...%@@@==@+-%%*%@%%%%*+*@@*=@@*#+**+%+*+@%@@+\n--::.=@@@@@.@@ +##*******++@:=+@@*##**+#+=+%@@*#=\n---:-@@@@@@-*@+:#**++==++==@.=#@%#*#**+#+==@@%@#*.\n==--=@@@@@@@=@@.*%#++=++*++@.+@@%##%+*+*+**@@@%##="

const DYLAN_NAME_ASCII = " _____   ___      _   _  _    ___ _    _____   _____ ___\n|   \\ \\ / / |    /_\\ | \\| |  / __| |  / _ \\ \\ / / __| _ \\\n| |) \\ V /| |__ / _ \\| .` | | (_ | |_| (_) \\ V /| _||   /\n|___/ |_| |____/_/ \\_\\_|\\_|  \\___|____\\___/ \\_/ |___|_|_\\"

function revealSecret(innerHtml) {
  if (document.querySelector(".konami-toast")) return

  if (!prefersReducedMotion()) {
    const crt = document.createElement("div")
    crt.className = "konami-crt"
    crt.setAttribute("aria-hidden", "true")
    document.body.appendChild(crt)

    const reveal = document.createElement("div")
    reveal.className = "konami-reveal"
    reveal.setAttribute("aria-hidden", "true")

    const portrait = document.createElement("pre")
    portrait.className = "konami-portrait"
    portrait.textContent = DYLAN_ASCII
    reveal.appendChild(portrait)

    const nametag = document.createElement("pre")
    nametag.className = "konami-nametag"
    nametag.textContent = DYLAN_NAME_ASCII
    reveal.appendChild(nametag)

    document.body.appendChild(reveal)

    setTimeout(() => {
      crt.remove()
      reveal.remove()
    }, 2600)
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
    '<span aria-hidden="true">▲▲▼▼◄►◄►</span> <strong>SECRET UNLOCKED</strong>' +
      '<span class="konami-body">You found the dev console. ' +
      '<a href="/docs/colophon">See how this site is built →</a></span>',
  )
}

const GRID_CELL_PX = 40
const GRID_SPAWN_MS = 750
const GRID_CELL_LIFE_MS = 2600
const GRID_MAX_CELLS = 6
const GRID_TEXT_PAD = 20

const BATTLESHIP_SCORE = 10
const BS_SIZE = 6
const SHIP_NAMES = { 3: "submarine", 4: "destroyer", 5: "aircraft carrier" }
// Stylized ASCII title shown above the board. Contains no HTML-special chars, so it's
// safe to interpolate into the panel markup; backslashes are pre-escaped for JS.
const BATTLESHIP_ASCII =
  " ___   _ _____ _____ _    ___ ___ _  _ ___ ___\n" +
  "| _ ) /_\\_   _|_   _| |  | __/ __| || |_ _| _ \\\n" +
  "| _ \\/ _ \\| |   | | | |__| _|\\__ \\ __ || ||  _/\n" +
  "|___/_/ \\_\\_|   |_| |____|___|___/_||_|___|_|"

function bsRandInt(min, max) {
  return min + Math.floor(Math.random() * (max - min + 1))
}

// Place 3-4 non-overlapping (but possibly touching) ships of length 3-5 in a size×size grid.
function placeBattleshipFleet(size) {
  const count = bsRandInt(3, 4)
  const ships = []
  const occupied = new Set()
  let attempts = 0

  while (ships.length < count && attempts < 800) {
    attempts += 1
    const len = bsRandInt(3, 5)
    const horizontal = Math.random() < 0.5
    const maxR = horizontal ? size - 1 : size - len
    const maxC = horizontal ? size - len : size - 1
    if (maxR < 0 || maxC < 0) continue

    const r0 = bsRandInt(0, maxR)
    const c0 = bsRandInt(0, maxC)
    const cells = []
    for (let i = 0; i < len; i += 1) {
      cells.push(horizontal ? `${r0},${c0 + i}` : `${r0 + i},${c0}`)
    }
    if (cells.some((key) => occupied.has(key))) continue

    cells.forEach((key) => occupied.add(key))
    ships.push({ len, name: SHIP_NAMES[len], cells, hits: new Set() })
  }
  return ships
}

// The easter-egg game: a bordered board over the hero where the visitor hunts hidden ships.
function initBattleship(hero, onExit) {
  const heroContent = hero.querySelector(".hero-content")

  const panel = document.createElement("div")
  panel.className = "battleship"
  panel.innerHTML = `
    <pre class="bs-ascii-title" aria-hidden="true">${BATTLESHIP_ASCII}</pre>
    <div class="bs-box">
      <div class="bs-header">
        <span class="bs-title">BATTLESHIP</span>
        <span class="bs-remaining">SHIPS REMAINING: <b data-bs-remaining>0</b></span>
      </div>
      <p class="bs-info" data-bs-info></p>
      <div class="bs-board" data-bs-board></div>
      <div class="bs-again" data-bs-again hidden>
        <span>All ships sunk! Play again?</span>
        <div class="bs-again-actions">
          <button type="button" data-bs-yes>Yes</button>
          <button type="button" data-bs-no>No</button>
        </div>
      </div>
    </div>
  `
  hero.appendChild(panel)
  if (heroContent) heroContent.classList.add("is-battleship-hidden")

  const board = panel.querySelector("[data-bs-board]")
  const remainingEl = panel.querySelector("[data-bs-remaining]")
  const infoEl = panel.querySelector("[data-bs-info]")
  const againEl = panel.querySelector("[data-bs-again]")

  let ships = []

  function shipsLeft() {
    return ships.filter((s) => s.hits.size < s.len).length
  }

  function newRound() {
    ships = placeBattleshipFleet(BS_SIZE)
    againEl.hidden = true
    infoEl.textContent = "Enemy fleet detected. Click the grid to find and sink the ships."
    remainingEl.textContent = String(ships.length)
    board.style.setProperty("--bs-cols", BS_SIZE)
    board.replaceChildren()
    for (let r = 0; r < BS_SIZE; r += 1) {
      for (let c = 0; c < BS_SIZE; c += 1) {
        const cell = document.createElement("button")
        cell.type = "button"
        cell.className = "bs-cell"
        cell.dataset.key = `${r},${c}`
        board.appendChild(cell)
      }
    }
  }

  function fire(cell) {
    if (cell.classList.contains("bs-hit") || cell.classList.contains("bs-miss")) return
    const key = cell.dataset.key
    const ship = ships.find((s) => s.cells.includes(key))

    if (!ship) {
      cell.classList.add("bs-miss")
      cell.textContent = "X"
      infoEl.textContent = "Miss."
      return
    }

    cell.classList.add("bs-hit")
    cell.textContent = "O"
    ship.hits.add(key)

    if (ship.hits.size === ship.len) {
      infoEl.textContent = `You sunk my ${ship.name}!`
      remainingEl.textContent = String(shipsLeft())
      if (shipsLeft() === 0) againEl.hidden = false
    } else {
      infoEl.textContent = "Direct hit!"
    }
  }

  board.addEventListener("click", (e) => {
    const cell = e.target.closest(".bs-cell")
    if (cell) fire(cell)
  })

  panel.querySelector("[data-bs-yes]").addEventListener("click", newRound)
  panel.querySelector("[data-bs-no]").addEventListener("click", () => {
    panel.remove()
    if (heroContent) heroContent.classList.remove("is-battleship-hidden")
    if (typeof onExit === "function") onExit()
  })

  newRound()
}

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

  // In-memory only, on purpose: the score resets on every page load — a refresh or
  // navigating to another page starts the grid game fresh.
  let score = 0
  let battleshipActive = false
  let battleshipStarted = false

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
      renderScore()

      if (!battleshipStarted && score >= BATTLESHIP_SCORE) {
        battleshipStarted = true
        battleshipActive = true
        sync() // stop spawning binary cells and clear the board while Battleship runs
        initBattleship(hero, () => {
          battleshipActive = false
          sync()
        })
      }
    })

    layer.appendChild(cell)
  }

  let timer = null
  let inView = false

  function sync() {
    if (inView && !document.hidden && !battleshipActive) {
      if (!timer) timer = setInterval(spawn, GRID_SPAWN_MS)
    } else if (timer) {
      clearInterval(timer)
      timer = null
      layer.replaceChildren()
    } else if (battleshipActive) {
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

// Project cards on the landing page open an expanded <dialog> with the full write-up,
// screenshots, and links. Native <dialog> gives us Escape-to-close, a focus trap, and
// focus restoration for free; we only wire the open trigger and backdrop-click close.
function initProjectModals() {
  const openers = document.querySelectorAll("[data-project-open]")
  if (!openers.length) return

  openers.forEach((opener) => {
    opener.addEventListener("click", () => {
      const dialog = document.getElementById(opener.getAttribute("data-project-open"))
      if (dialog && typeof dialog.showModal === "function") dialog.showModal()
    })
  })

  document.querySelectorAll("dialog.project-dialog").forEach((dialog) => {
    dialog
      .querySelectorAll("[data-project-close]")
      .forEach((btn) => btn.addEventListener("click", () => dialog.close()))

    // A click that lands on the dialog element itself (its ::backdrop) closes it;
    // clicks inside .project-dialog-inner never match and stay open.
    dialog.addEventListener("click", (event) => {
      if (event.target === dialog) dialog.close()
    })
  })
}

document.addEventListener("DOMContentLoaded", () => {
  initHero()
  initKonami()
  initProjectModals()
})
