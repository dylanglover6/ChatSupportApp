const MOBILE_BREAKPOINT = 900
const SCRAMBLE_TICK_MS = 50
const STAGGER_MIN_MS = 60
const STAGGER_MAX_MS = 90
const SPRING_STIFFNESS = 150
const SPRING_DAMPING = 14
const SPRING_ENERGY_EPSILON = 0.02

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
        letters.push({ el: letterSpan, char, x: 0, y: 0, vx: 0, vy: 0, targetX: 0, targetY: 0 })
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

function initPhysics(headline, letters, mobileMode) {
  let dragging = false
  let running = false
  let lastTime = performance.now()
  let lastScrollY = window.scrollY
  let pointerX = 0
  let pointerY = 0

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

      letters.forEach((letter) => {
        const rect = letter.el.getBoundingClientRect()
        const restX = rect.left + rect.width / 2 - letter.x
        const restY = rect.top + rect.height / 2 - letter.y
        const dist = Math.hypot(restX - pointerX, restY - pointerY)
        letter.dragFalloff = Math.max(0.15, 1 - dist / 400)
      })

      headline.setPointerCapture(event.pointerId)
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

    const endDrag = () => {
      if (!dragging) return
      dragging = false
      letters.forEach((letter) => {
        letter.targetX = 0
        letter.targetY = 0
      })
      wake()
    }
    headline.addEventListener("pointerup", endDrag)
    headline.addEventListener("pointercancel", endDrag)
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

function initHero() {
  const hero = document.getElementById("hero")
  if (!hero) return

  const headline = hero.querySelector(".hero-headline")
  const reducedMotion = prefersReducedMotion()
  const letters = splitHeadlineIntoLetters(headline)

  if (reducedMotion) {
    letters.forEach((letter) => {
      letter.el.textContent = letter.char
      letter.el.classList.remove("is-scrambled")
      letter.el.classList.add("is-resolved")
    })
  } else {
    runScrambleReveal(letters, () => initPhysics(headline, letters, isMobileMode()))
    initParallax(hero)
  }

  initReveal()
  initScrollspy()
}

document.addEventListener("DOMContentLoaded", initHero)
