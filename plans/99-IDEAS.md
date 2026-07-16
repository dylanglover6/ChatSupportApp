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

## Konami code easter egg on the portfolio
- What: ↑↑↓↓←→←→ triggers a retro effect (CRT flicker, coin sound, hidden doc link)
- Hooks in: `assets/js/portfolio.js`, any time after Phase 1
- Type: additive

## Visitor-facing ticket status page
- What: after leaving a message via the widget, visitor gets a link to check their ticket's status
- Hooks in: after Phase 4; new route + LiveView, ticket lookup token
- Type: additive-ish (new route, no schema change if token stored on ticket)

## SLA timers / workload analytics on DylanSupport
- What: per-ticket age timers and per-agent workload charts on the desk index
- Hooks in: after Phase 4; `ticket_live/index.ex`
- Type: additive

## Light mode theme
- What: alternate light palette behind a `[data-theme="light"]` toggle. Technically just
  a second `:root` token block (nothing hardcodes colors), but the real work is design:
  pixel yellow fails contrast on white, so the accent, glow, scanline, and hard-shadow
  treatments all need light-mode equivalents. Only worth it if dark-mode docs
  readability proves to be a real problem.
- Hooks in: `app.css` tokens + a toggle in the layout; anytime, but design-review every page
- Type: additive in code, architectural in design — decide deliberately, not mid-phase

## Interactive hero background grid (click-to-score easter egg)
- What: the hero's background pixel grid (`.hero-bg-grid`) randomly fades 1s and 0s into
  random grid cells over time; clicking a lit cell increments a persistent score counter
  shown in the top-left corner (localStorage-backed, so it survives reloads). Hitting a
  specific score threshold triggers a hidden easter egg (CRT flicker, a secret DylanDocs
  link, something in that vein).
- Hooks in: `.hero-bg-grid` markup/CSS, `assets/js/portfolio.js` (Phase 1 hero); needs its
  own rAF-or-interval loop that stays independent of the letter-physics loop and sleeps
  when the hero isn't in view.
- Type: additive