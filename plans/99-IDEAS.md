# 99 — Ideas & Backlog (parking lot)

> **For Claude Code: DO NOT implement anything in this file.** This is a backlog of
> ideas captured outside the current build phases. Only implement an item here when a
> prompt explicitly names it. When asked to "triage" this file, assess each item's
> current cost given the codebase state and report — still don't implement.
>
> **For Dylan:** add ideas anytime, in any state of roughness. Template:
>
> ```
> ## Idea name
> - What: one or two lines
> - Hooks in: phase / files / route it touches
> - Type: additive (safe anytime) | architectural (needs a decision)
> ```

---

## Deploy to a real URL (Fly.io)
- What: host the app so recruiters can visit without a local setup; swap Ollama for a hosted LLM API or lean on the fallback responses
- Hooks in: post-MVP; `config/runtime.exs`, `AI.Client` adapter, Dockerfile
- Type: architectural

## Rename OTP app SupportBot → something Dylan-branded
- What: full module/app rename now that branding is settled (`support_bot` → e.g. `dylan_hq`)
- Hooks in: post-MVP, every file; mechanical but wide
- Type: architectural

## Vector search for DylanDocs / bot grounding
- What: replace keyword KB search with embeddings (pgvector) for better bot answers
- Hooks in: `kb/search.ex`, `AI.Client`, new migration
- Type: architectural

## Streaming bot responses
- What: token-by-token streaming in the widget instead of waiting for full replies (Ollama supports it)
- Hooks in: Phase 3+; `AI.Client`, `WidgetLive`
- Type: architectural (changes the client/LiveView message flow)

## Konami code easter egg on the portfolio ✅ SHIPPED
- What: ↑↑↓↓←→←→ triggers a retro effect (CRT flicker, coin sound, hidden doc link)
- Hooks in: `assets/js/portfolio.js`, any time after Phase 1
- Type: additive
- Shipped: ↑↑↓↓←→←→BA → CRT flicker + toast linking to the colophon. No audio asset.

## Visitor-facing ticket status page ✅ SHIPPED
- What: after leaving a message via the widget, visitor gets a link to check their ticket's status
- Hooks in: after Phase 4; new route + LiveView, ticket lookup token
- Type: additive-ish (new route, no schema change if token stored on ticket)
- Shipped: `tickets.public_token` + `/status/:token` (`StatusLive`, read-only, no internal
  notes); widget/chat confirmations link there.

## SLA timers / workload analytics on DylanSupport ✅ SHIPPED
- What: per-ticket age timers and per-agent workload charts on the desk index
- Hooks in: after Phase 4; `ticket_live/index.ex`
- Type: additive
- Shipped: Desk Overview stat tiles, per-agent workload meters, SLA age coloring.

## Light mode theme
- What: alternate light palette behind a `[data-theme="light"]` toggle. Technically just
  a second `:root` token block (nothing hardcodes colors), but the real work is design:
  pixel yellow fails contrast on white, so the accent, glow, scanline, and hard-shadow
  treatments all need light-mode equivalents. Only worth it if dark-mode docs
  readability proves to be a real problem.
- Hooks in: `app.css` tokens + a toggle in the layout; anytime, but design-review every page
- Type: additive in code, architectural in design — decide deliberately, not mid-phase

## Interactive hero background grid (click-to-score easter egg) ✅ SHIPPED
- What: the hero's background pixel grid (`.hero-bg-grid`) randomly fades 1s and 0s into
  random grid cells over time; clicking a lit cell increments a persistent score counter
  shown in the top-left corner (localStorage-backed, so it survives reloads). Hitting a
  specific score threshold triggers a hidden easter egg (CRT flicker, a secret DylanDocs
  link, something in that vein).
- Hooks in: `.hero-bg-grid` markup/CSS, `assets/js/portfolio.js` (Phase 1 hero); needs its
  own rAF-or-interval loop that stays independent of the letter-physics loop and sleeps
  when the hero isn't in view.
- Type: additive

## Hidden "Battleship" mini-game (unlocked at grid score 10) ✅ SHIPPED
- What: reaching binary-grid score 10 slides the hero text away and drops in a playable
  Battleship board — 4–6 random ships (recon boat/sub/destroyer/carrier), yellow-◯ hits,
  white-✕ misses, "You sunk my ___!", "Play again?". Documented on the hidden `easter-eggs`
  KB page so DylanBot can describe it when asked.
- Hooks in: `assets/js/portfolio.js` (`initBattleship`, hooked off `initHeroGrid`), `app.css`.
- Type: additive

---

# Easter-egg backlog (arcade-vibe, easy additive wins)

> All additive, client-side, no schema. Each is a small `portfolio.js` + `app.css` change.
> Add the good ones to the hidden `easter-eggs.md` KB page so DylanBot can reveal them.

## "Watch the AI solve it" mode for Battleship
- What: a small button on the Battleship board that lets a hunt/target AI play the current
  board on its own, optionally with a probability-density heatmap — shows off the algorithm
  instead of hiding it. (This is the cheap version of a full head-to-head game.)
- Hooks in: `assets/js/portfolio.js` (reuse the blind hunt/target logic already prototyped).
- Type: additive

## Arcade attract-mode when the hero goes idle
- What: after ~20s of no interaction on the landing hero, drift the letters gently and blink
  an "INSERT COIN" / "PRESS ANY KEY" prompt like an arcade cabinet's demo screen; any input
  dismisses it. Ties the whole hero together thematically.
- Hooks in: `assets/js/portfolio.js` (idle timer alongside the physics loop), `app.css`.
- Type: additive

## Playable `$ man dylan` terminal
- What: the homepage terminal window (`$ man dylan`) becomes a tiny fake shell that accepts
  a handful of commands: `help`, `whoami`, `ls projects`, `cat resume`, `sudo hire-dylan`
  (easter-egg response). Retro, on-brand, and doubles as a second way to navigate.
- Hooks in: `page_html/home.html.heex` terminal block + a small `portfolio.js` input handler.
- Type: additive

## DylanBot secret phrases
- What: a few phrases typed to DylanBot trigger special canned replies / ASCII art before the
  normal flow — e.g. "do a barrel roll", "the answer to everything" → 42, "sudo hire dylan",
  "up up down down". Pure delight, and reinforces the bot has personality.
- Hooks in: `AI.Client` (or a pre-check in the chat/widget LiveViews before the model call).
- Type: additive

## "ACHIEVEMENT UNLOCKED" toasts + a finds tracker
- What: each easter egg found pops a pixel "ACHIEVEMENT UNLOCKED" toast and records it in
  localStorage; a subtle counter (e.g. footer "secrets: 3/6") rewards completionists. Gives
  the scattered eggs a light meta-game spine.
- Hooks in: `assets/js/portfolio.js` (shared `unlock(id)` helper), `app.css` toast styles.
- Type: additive

## Battleship high score (fewest shots)
- What: track the best "ships sunk in N shots" run in localStorage and show a "BEST: 27"
  line on the Battleship board, giving the mini-game replay value.
- Hooks in: `assets/js/portfolio.js` (`initBattleship`).
- Type: additive

## Binary cursor trail in the hero
- What: a faint trail of 1s and 0s follows the cursor while it's over the hero, echoing the
  grid game. Cheap, atmospheric, disables under reduce-motion / on touch.
- Hooks in: `assets/js/portfolio.js` (pointer handler on the hero), `app.css`.
- Type: additive