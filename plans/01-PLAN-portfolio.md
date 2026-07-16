# Plan 01 — Portfolio Site (Phases 0–1)

> **For Claude Code:** Prereq: read `00-OVERVIEW.md` (architecture, design tokens, build
> order). This plan covers Phase 0 (foundation) and Phase 1 (portfolio landing page)
> inside the existing ChatSupportApp Phoenix project. Complete each phase's acceptance
> criteria before moving on.

---

## Phase 0 — Foundation (design system, layout shell, routes)

### 0.1 Design tokens & fonts

- Create/replace the base stylesheet with the "Dark Arcade" tokens from
  `00-OVERVIEW.md` §4. Current CSS lives at `priv/static/assets/app.css`; keep that
  pipeline unless the project already builds CSS through esbuild — do not introduce
  Tailwind or a new build step for the MVP.
- Download woff2 files for **Press Start 2P**, **VT323**, **Inter** into
  `priv/static/fonts/` and declare `@font-face` locally (offline-safe demo).
- Define base element styles: body bg/text, headings in pixel font with hard shadow,
  links (yellow underline offset), buttons (border-invert hover per overview), focus
  outlines (2px yellow, never removed), `::selection`, scrollbar styling (dark track,
  yellow thumb — cosmetic, fine to skip on Firefox).
- Add utility classes used across the app: `.pixel-card` (raised bg, 2px border),
  `.badge` (pixel font, tiny), `.btn`, `.btn-primary`, `.scanlines` overlay helper.
- Implement the `--bg-glow` CRT vignette (Overview §4 "Signature effects"): a
  radial-gradient on `body` from `--bg-glow` to transparent, ellipse centered near the
  top of the viewport, low opacity. Sitewide, most visible behind the hero. Re-check
  the muted-text contrast criterion after adding it.

### 0.2 Root layout & navigation shell

- Rework `lib/support_bot_web/components/layouts/` so there is one root layout that:
  - renders the **left sticky sidebar nav** (desktop) — transparent background with
    `backdrop-filter: blur(8px)`, thin right border, vertical list: Home, About,
    Projects, Resume, DylanDocs, DylanSupport. Active item gets yellow text + a small
    pixel marker (▸ or a 6px square).
  - renders a slim top bar instead on mobile (`< 900px`): pixel "DG" monogram + hamburger
    button toggling a full-screen overlay menu (dark, big pixel links, closes on tap).
    Pure CSS + a few lines of JS; no framework.
  - includes the **DylanBot widget mount point** (implemented in Plan 02, Phase 3 — for
    now render the collapsed FAB as a non-functional placeholder so layout spacing is
    settled early).
- Nav behavior on the portfolio page (`/`): links are anchor links (`#about`, etc.) with
  scrollspy highlighting (Phase 1.3). On other pages (`/docs`, `/support`): same sidebar,
  links go to routes, active state = current route.

### 0.3 Route renames

In `lib/support_bot_web/router.ex`:

- `/` → new `PageController#home` (portfolio landing).
- `/kb` → `/docs`, `/kb/:slug` → `/docs/:slug` (keep the LiveView modules; add
  permanent redirects from the old paths).
- `/tickets` → `/support`, `/tickets/:id` → `/support/:id` (same redirect treatment).
- `/chat` stays.
- Verify nothing else hardcodes old paths (`grep -r "/kb\|/tickets" lib/`) — update
  `push_navigate`/`~p` sigils accordingly.

**Phase 0 acceptance criteria**

- [ ] App compiles and boots; all pages render with dark theme, pixel headings, yellow accents.
- [ ] Old `/kb` and `/tickets` URLs redirect to `/docs` and `/support`.
- [ ] Sidebar shows on every page ≥900px; hamburger overlay works below 900px.
- [ ] Fonts load with no network (disconnect and reload to verify).

---

## Phase 1 — Portfolio landing page (`/`)

One long controller-rendered page (`page_html/home.html.heex`), sections in order:
`#hero`, `#about`, `#projects`, `#resume`, `#docs-teaser`, `#contact`. All interactivity
is vanilla JS in `assets/js/` (new `portfolio.js`, imported from `app.js`, guarded to
only run when `#hero` exists).

### 1.1 Hero — "Howdy!"

- Full-viewport (`min-height: 100svh`), full-width hero.
- Headline is one `<h1>` with two lines (keep a single h1 for a11y/SEO; use a `<br>` or
  block spans inside it):
  - Line 1: `HOWDY!` — Press Start 2P, the big display line.
  - Line 2: `My name is Dylan Glover.` — same pixel font at roughly half the size
    (or VT323 if Press Start 2P reads too dense at that length; try both).
- Subline below the h1, in VT323: `Thanks for stopping in — got a question? Just Chat.`
  (final copy — deliberately ends on "Chat" so the idle cursor parks right next to the
  call-to-action; see "Cursor & subline sequencing" below for how it appears).
- **Headline markup for effects:** server-render the headline as plain text inside the
  `<h1>` (SEO/no-JS safe). On load, JS splits it into per-letter `<span>`s; set
  `aria-label` with the full text on the `<h1>` and `aria-hidden="true"` on the spans so
  screen readers hear one clean sentence. Letters get `display: inline-block` and
  `will-change: transform` (spaces preserved as fixed-width spans).
- **Matrix scramble reveal (replaces any typewriter idea):** applies to both headline
  lines as one sequence (line 1 resolves first, line 2 follows). On first load each
  letter initially shows a random `0` or `1`, re-randomized every ~28ms (revised faster
  than an earlier ~50ms pass — should feel snappier/more urgent) with a subtle
  dimmer yellow (`--accent-dim`) while scrambled. Letters resolve to their true
  character left-to-right on a staggered schedule with slight randomness (~35–55ms
  stagger), full reveal completing in **~0.8–1.4s total** across both lines. On resolve, a letter snaps to full
  `--accent`/`--text` styling. After the last letter resolves, the physics behavior
  below activates. The scramble runs once per full page load — not on live navigation
  back to `/`.
- **Physics headline (vanilla rAF springs — no library):** each letter span carries
  spring state `{x, y, vx, vy}` integrated in the shared rAF loop
  (semi-implicit Euler; stiffness ≈ 170, damping ≈ 9 — revised more underdamped than an
  earlier pass: aim for **2–3 visible overshoot bounces** before rest, not just one):
  - *Scroll inertia:* sample scroll velocity per frame (one `scrollY` read); inject a
    clamped vertical impulse into each letter, staggered slightly by index, so the
    headline lags the scroll and **jiggles for a moment after scrolling stops**.
  - *Drag with weight:* `pointerdown` on the headline starts a drag — letters spring
    toward the pointer offset with lag falling off by distance from the grab point
    (nearest letters follow tightest). On `pointerup`, letters spring back to rest with
    visible overshoot. Use pointer events (mouse + touch unified),
    `touch-action: pan-y` on the headline so vertical page scroll still works on touch.
  - **Fix: drag must never "stick" to the pointer.** If a fast release lands while the
    pointer is no longer over the headline element (or has left the window), a handler
    scoped to the element alone can miss the up event and leave `isDragging` stuck true.
    Fix at the root: call `element.setPointerCapture(pointerId)` on `pointerdown` so the
    browser keeps routing `pointermove`/`pointerup` to the element regardless of where
    the pointer ends up; release capture on `pointerup`. Also treat `pointercancel`,
    `lostpointercapture`, and window `blur`/`visibilitychange` as safety nets that force
    `isDragging = false`. Use Pointer Events exclusively (not `mousedown`/`mousemove`)
    so mouse and touch share one correct code path.
  - *Whip glitch:* when any letter's instantaneous speed exceeds a threshold during
    recoil (i.e. it's whipping back fast), briefly swap its rendered glyph to a random
    `0`/`1` in the scramble's dim-accent style for ~80–120ms before it snaps back to the
    true character — localized to only the fastest-moving letters in that moment, not
    the whole headline. Reuses the scramble's glyph-swap logic; just gated by velocity
    instead of the initial-load timeline.
  - *Performance:* physics writes `transform: translate()` **on the letter spans only**;
    the parallax handler writes transforms **on the layer containers only** — two
    systems, two element sets, no conflict. Put the loop to sleep when total kinetic
    energy drops below an epsilon and no drag is active; wake on scroll/pointer events.
- **Fallbacks & mobile:** under `prefers-reduced-motion`, skip the scramble entirely
  (text shows instantly) and disable all physics. Below 900px / coarse pointers: keep
  the scramble, disable scroll-inertia and drag, and instead enable **tap wobble** — a
  tap on the headline fires one clamped impulse into the letters (strongest at the tap
  point, falling off by distance) and they spring back to rest through the same spring
  system as desktop. Tap handling must never block or delay page scrolling
  (`touch-action: pan-y` stays; no `preventDefault` on touch moves).
- **Cursor & subline sequencing:** once the headline fully resolves, a blinking block
  cursor (`█`, `--accent`, ~530ms blink interval) appears immediately after
  "Dylan Glover." and blinks in place for ~500ms. It then jumps down to the start of
  the subline, which types out character-by-character (~35ms/char, plain terminal
  reveal — no scramble) with the cursor trailing the last typed character. Once the
  subline finishes, the cursor keeps blinking at the end of the sentence indefinitely —
  a permanent piece of the hero's character, not just a loading state, and it lands
  right after "Chat." by design. Under `prefers-reduced-motion`, skip straight to the
  fully-typed end state with a static (non-blinking) cursor.
- **Parallax layers** (back → front): (1) faint pixel grid / starfield background,
  (2) drifting pixel-art clouds or floating 8-bit shapes in dim yellow, (3) headline +
  subline, (4) scanline overlay fixed on top. A "scroll" hint arrow (pixel chevron,
  gentle bounce) at the bottom.
- Parallax implementation: one `requestAnimationFrame` scroll handler translating each
  layer by `scrollY * factor` (factors ~0.15 / 0.35 / 0.6), `will-change: transform`,
  fully disabled under `prefers-reduced-motion` and below 900px (mobile gets a static
  hero — parallax on touch is jank-prone).
- As the user scrolls out of the hero, sections below reveal with a small
  translate-up + fade via `IntersectionObserver` (`.reveal` class, once per element).

### 1.2 Sections

- **About (`#about`)** — two-column ≥900px, stacked below. Left: avatar/headshot
  (pixelated border treatment), short bio paragraphs (`TODO(dylan)`). Right: **skills
  grid** — the decided home for technical skills (see overview §6): small `.pixel-card`
  tiles grouped under LANGUAGES / FRAMEWORKS / TOOLS headers, each tile = name + optional
  1–3 filled squares (■■□) for proficiency. Below the grid a link: "Full breakdown in
  DylanDocs →" (`/docs`).
- **Projects (`#projects`)** — responsive card grid (1col mobile / 2col / 3col wide).
  Each `.pixel-card`: project name (pixel font), one-liner, stack badges, links (GitHub /
  live). First card is **this platform itself** ("You're looking at it — Phoenix
  LiveView + Ollama, see DylanDocs for the case study"). Data lives as a module attribute
  list in the controller or a `priv/projects.exs` — not hardcoded in HEEx — so adding a
  project is a one-line change. `TODO(dylan)` seed with SupportBot + 2 placeholders.
- **Resume (`#resume`)** — short section: one sentence + big primary button
  `DOWNLOAD RESUME [PDF]` → `href="/resume.pdf" download`. Place the file at
  `priv/static/resume.pdf` (`TODO(dylan)`: supply real PDF; ship a placeholder that says
  placeholder). Secondary link: "or read the extended version in DylanDocs".
- **DylanDocs teaser (`#docs-teaser`)** — styled like a terminal window (VT323):
  `$ man dylan` and 2–3 output lines, plus a button `OPEN DYLANDOCS →` (`/docs`) and a
  hint: "…or just ask DylanBot in the corner".
- **Contact (`#contact`)** — email link, GitHub, LinkedIn (`TODO(dylan)` for URLs).
  Footer: tiny pixel text "Built with Phoenix LiveView + Ollama · © 2026 Dylan Glover".

### 1.3 Scrollspy sticky nav (portfolio page)

- `IntersectionObserver` over the section elements (`rootMargin: "-40% 0px -55% 0px"`)
  toggles the sidebar's active link. Smooth-scroll on click
  (`scroll-behavior: smooth` on `html`, disabled under reduced motion).
- Mobile: sections are plain stacked; the overlay menu's anchor links close the menu
  then scroll.

### 1.4 Mobile responsiveness checklist

- Breakpoints: 600px (single column everywhere), 900px (sidebar appears, grids widen).
- Hero headline scales via `clamp()` (Press Start 2P wraps badly — test at 320px width).
- Touch targets ≥44px in the overlay menu and widget FAB.
- No horizontal scroll at 320/375/768/1024/1440 widths.

**Phase 1 acceptance criteria**

- [ ] Hero renders full-viewport; scramble reveal resolves both headline lines ("HOWDY!" / "My name is Dylan Glover.") within ~1.4s of load; parallax works on desktop; mobile hero is static and clean.
- [ ] After scrolling stops, the headline visibly jiggles/bounces (2–3 overshoots) and settles; dragging the headline and releasing springs back with overshoot; vertical touch scroll over the headline still scrolls the page.
- [ ] Release the drag while the pointer is still moving fast (including releasing off the element/window) — the headline must let go immediately, never "stick" to the pointer requiring a second click.
- [ ] During a fast whip-back, the fastest-moving letters briefly flash 0/1 glyphs before settling to real characters.
- [ ] Cursor blinks after "Dylan Glover.", then the subline types out and the cursor idles at the end, next to "Chat."; "Chat" is a visually distinct, clickable element more prominent than the resume button.
- [ ] On a touch device (or DevTools touch emulation), tapping the headline makes nearby letters wobble and settle; tapping never interferes with scrolling.
- [ ] Physics loop sleeps when settled (verify no continuous rAF work in DevTools Performance when idle).
- [ ] Screen reader reads the headline as one sentence (aria-label intact, spans hidden).
- [ ] Sidebar highlights the correct section while scrolling; clicking navigates smoothly.
- [ ] All five sections present, populated with real content or clearly-marked `TODO(dylan)` placeholders.
- [ ] `/resume.pdf` downloads.
- [ ] `prefers-reduced-motion` shows the headline instantly (no scramble), with parallax, physics, and reveals all disabled.
- [ ] Lighthouse quick pass: no contrast failures for body text (muted text ≥ 4.5:1 on `--bg`) — re-verify after adding the `--bg-glow` layer from Phase 0.1, since it changes what's effectively behind the text.

**Then proceed to `02-PLAN-dylandocs-support.md`.**
