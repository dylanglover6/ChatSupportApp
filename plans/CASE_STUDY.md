# Plot Twist

**A mobile-first, full-stack MERN web app for sending temporary, scratch-to-reveal invite links** — for trips, parties, and any plan that deserves a little drama.

| | |
|---|---|
| **Role** | Solo build |
| **Stack** | MERN (MongoDB · Express · React · Node) |
| **Type** | Mobile-first web app |
| **Year** | 2026 |
| **Repo** | [github.com/dylanglover6/PlotTwist](https://github.com/dylanglover6/PlotTwist) |

---

## What it is

Plot Twist turns an ordinary invitation into a moment. You build a reveal page, choose when it unlocks, and send a single link. The recipient first sees a locked teaser and a live countdown — then, at the unlock time, they scratch the screen to uncover where you're taking them. The link is **temporary**: once it expires, the surprise is gone for good.

- **3** reveal states, zero stored
- **1** pure function as the source of truth
- **5** screens in the reveal flow
- **1** service to deploy

---

## Technology

Built end to end in JavaScript: a React front end talking to an Express and MongoDB back end, all running on Node.

### The MERN core

| Tech | Role in the app |
|---|---|
| **MongoDB** (Atlas · Mongoose 8) | The database. Invites are persisted through Mongoose schemas that enforce field limits and validation at the data boundary. |
| **Express** (v4) | The server. API routing, static hosting of the built client, and a centralized error layer that maps Mongoose errors to HTTP status codes. |
| **React** (v19) | The UI. Component-driven, with a custom `useInvite` hook centralizing data loading and a shared reveal-state helper. |
| **Node.js** (v20+) | The runtime beneath both the dev tooling and the production server — one language across the whole stack. |

### Front-end supporting cast

| Tech | Role |
|---|---|
| **React Router** (v7) | Client-side routing: `/`, `/create`, `/created/:id`, `/t/:id`, `/t/:id/more`. |
| **Tailwind CSS** (v3 · PostCSS) | Utility-first styling wired to CSS-variable design tokens, so the whole theme is driven from one place. |
| **lucide-react** | Icon set. |

### Build & quality tooling

`Vite 7` (dev server + bundler) · `Vitest` (unit tests) · `ESLint 9` (flat config) · `Prettier` · `nodemon` · `concurrently` · `cross-env`

The repo is structured as an **npm-workspaces monorepo** — `client` and `server` live as separate workspaces under one repo, sharing a single install and one set of lint/format/test scripts.

### Why MERN?

I'd worked with the MERN stack before, so it was the natural choice. Reaching for tools I already knew let me spend my time on the parts that make Plot Twist itself — the reveal timing and the scratch-to-reveal interaction — instead of relearning the plumbing. Running a single JavaScript language from database queries to UI also kept the context switching low while building solo.

---

## The core idea: state you derive, never store

An invite is always in one of three states — **locked**, **revealed**, or **expired** — and I deliberately never persist that state. It's derived on the fly from two server-generated timestamps, `unlockAt` and `expiresAt`, compared against the current time. One small pure function is the single source of truth, which made the behavior trivial to reason about and to unit-test at the exact boundaries.

```
 locked                 revealed                expired
 now < unlockAt   ──►    unlockAt ≤ now ≤       ──►   now > expiresAt
 (teaser +               expiresAt                    (link is gone)
  countdown)             (scratch to reveal)

 getRevealState(invite, now) → "locked" | "revealed" | "expired"
```

---

## Architecture: one service, front to back

In development the React app runs on Vite and proxies `/api` calls to Express. In production, Express serves both the built React bundle and the API from a single process — so the whole app deploys as one unit, with no separate frontend host to wire up. Image search is proxied through the backend so the Unsplash API key never touches the browser.

```
                 ┌──────────────────────────────────────────┐
  Browser  ───▶  │  Express (Node)                           │
  React SPA      │   • /api/*  → JSON API (Mongoose)         │
                 │   • /*      → built SPA + client routing  │
                 └───────────────┬──────────────────────────┘
                                 │
                        ┌────────▼────────┐      ┌──────────────┐
                        │  MongoDB Atlas  │      │ Unsplash API │
                        │  (invite store) │      │ (proxied)    │
                        └─────────────────┘      └──────────────┘
```

---

## How it was built

1. **Get the core loop working.** A rough draft first: create an invite, save it to MongoDB, generate a share link, and render the locked, revealed, and expired states end to end.
2. **Harden it for real use.** Set up ESLint and Prettier, removed dead code, refactored duplicated logic into shared hooks and components, and added error handling for bad input, failed requests, and empty states.
3. **Test the part that matters.** Wrote unit tests around the reveal-state logic, covering the exact unlock and expiry boundaries so the timing behavior can't silently regress.
4. **Build a design system.** Extracted colors, spacing, radii, and shadows into CSS variables so the entire look is re-themable from one place, then normalized the buttons and inputs.
5. **Accessibility & production.** Got to zero accessibility violations, added social and meta tags, and set up Express to serve the production build as a single deployable service.

---

## Feature highlights

- **Scratch-to-reveal** — a canvas overlay you physically scratch away, with the image blurring into focus underneath as you go.
- **Live countdown** — a per-second countdown to the unlock moment, with an emphasized final ten seconds.
- **Add to calendar** — generates an `.ics` file on the fly so recipients can save the reveal.
- **Image search** — search Unsplash for the reveal photo, proxied through the backend to protect the key.
- **Native sharing** — uses the Web Share API where available, falling back to copy-to-clipboard.
- **Optional info page** — hosts can attach a secondary page for itineraries, addresses, or packing notes.

---

_Built by Dylan Glover · A solo full-stack MERN project · polished and deploy-ready._
