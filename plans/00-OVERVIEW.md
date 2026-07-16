# Dylan Glover — Portfolio Platform: Master Plan

> **For Claude Code:** Read this file first. It holds the architecture, design system,
> and build order shared by the two implementation plans. Then execute the plans in order:
> `01-PLAN-portfolio.md` → `02-PLAN-dylandocs-support.md`. Work phase by phase; each phase
> lists acceptance criteria. Do not skip Phase 0 — every later phase depends on it.

## 1. Vision

One Phoenix LiveView application that is both Dylan's portfolio site **and** the flagship
project it showcases. Visitors land on a modern dark portfolio page, browse DylanDocs
(documentation about Dylan instead of the old fake FlowDesk product), chat with a
page-aware support bot from any page, and — behind the scenes — a DylanSupport agent desk
manages tickets the bot escalates.

The existing repo is https://github.com/dylanglover6/ChatSupportApp (Phoenix LiveView,
Ecto/PostgreSQL, Ollama at `http://localhost:11434` with `llama3.2`, markdown KB in
`priv/kb`, deterministic fallback when Ollama is offline).

## 2. Architecture decision (settled)

**Everything is served from the single existing Phoenix app.** No Docusaurus, no separate
static site.

Why this is the right call:

- The chat widget must persist on every page — trivially done with one root layout and a
  `live_render`-ed widget LiveView; nearly impossible to do cleanly across two apps.
- The KB loader (`lib/support_bot/kb/loader.ex` + `search.ex`) already parses markdown
  files with title/slug metadata. DylanDocs is an evolution of it, not a new system.
- One design system in one `app.css` carries the styling across portfolio, docs, chat,
  and support desk — exactly what Dylan asked for.
- Portfolio differentiation: the site itself demonstrates Elixir/Phoenix/LiveView,
  PubSub-powered live chat takeover, and local LLM integration.

**Module naming:** keep the `SupportBot` / `support_bot_web` internal namespaces for the
MVP (renaming an Elixir app touches every file for zero functional gain). Rebrand only
user-facing strings: the bot is **"DylanBot"**, docs are **"DylanDocs"**, the agent desk
is **"DylanSupport"**. An optional post-MVP task can rename the OTP app.

**Runtime target:** local demo (`mix phx.server`, Postgres local, Ollama local).
Hosting is explicitly out of MVP scope; the AI client already degrades gracefully to
fallback responses, so nothing blocks a later Fly.io deploy.

## 3. Route map (target state)

| Route | What | Implementation |
|---|---|---|
| `/` | Portfolio landing (hero, about+skills, projects, resume, docs teaser, contact) | Controller-rendered page + vanilla JS scroll effects |
| `/docs` | DylanDocs index with category sidebar | LiveView (evolved `kb_live/index.ex`) |
| `/docs/:slug` | Single doc page, rendered markdown, prev/next | LiveView (evolved `kb_live/show.ex`) |
| `/support` | DylanSupport agent desk (ticket queue, agents, activity) | LiveView (evolved `ticket_live/index.ex`) |
| `/support/:id` | Ticket workspace (history, email sim, chat takeover) | LiveView (evolved `ticket_live/show.ex`) |
| `/chat` | Full-page chat (kept as a bigger version of the widget) | Existing `chat_live.ex`, restyled |
| `/resume.pdf` | Resume download | Static file in `priv/static/` |
| *(every page)* | DylanBot floating chat widget, bottom-right | `WidgetLive` rendered in the root layout |

Old `/kb` and `/tickets` routes get redirects to `/docs` and `/support`.

## 4. Design system — "Dark Arcade"

Defined once in `assets/css/` (or `priv/static/assets/app.css` per current setup) as CSS
custom properties. **Every page uses these tokens. No hardcoded colors anywhere else.**

```css
:root {
  /* surfaces */
  --bg:          #0b0c10;   /* page background — near-black blue */
  --bg-raised:   #14161c;   /* cards, panels */
  --surface:     #1b1e26;   /* inputs, chat bubbles */
  --border:      #2a2e38;
  --bg-glow:     #241f10;   /* warm dim amber haze — "old monitor" glow behind content */
  /* text */
  --text:        #e8e6e3;
  --text-muted:  #9a948a;
  /* the yellow */
  --accent:      #ffd23f;   /* primary pixel yellow */
  --accent-dim:  #c9a227;   /* hard shadows, hover-out states */
  --accent-glow: rgba(255, 210, 63, 0.14);
  /* status */
  --ok:          #6ee7a0;
  --warn:        #ffb454;
  --danger:      #ff5c5c;
  --info:        #7aa2f7;
}
```

**Typography**

- Pixel display font: **"Press Start 2P"** — hero headline, section headings (h1/h2),
  nav labels, badges, the widget's "DYLANBOT" header. Always uppercase-ish, small sizes
  (h2 ≈ 18–22px; the font is dense). Self-host the woff2 in `priv/static/fonts/` so the
  local demo works offline.
- Secondary pixel font: **"VT323"** for larger blocks of stylized text (terminal-style
  taglines, stat counters) where Press Start 2P would be unreadable.
- Body font: **Inter** (or system-ui stack) for all paragraphs, docs content, ticket
  text. Pixel fonts are decoration, never body copy — this keeps docs readable.

**Signature effects (use consistently, sparingly)**

- Hard pixel shadow on headings: `text-shadow: 3px 3px 0 var(--accent-dim);`
- Square corners everywhere: `border-radius: 0` (buttons, cards, chat bubbles). The one
  exception: the widget FAB may be a rounded square (8px).
- 2px solid or dotted `--border` borders; accent border on hover/focus.
- Buttons: dark surface, yellow 2px border, yellow text; on hover invert (yellow bg,
  dark text) with a 2px translate "button press" effect.
- Hero scanline overlay: subtle repeating-linear-gradient, opacity ~0.04.
- CRT monitor glow: a low-opacity radial gradient (`--bg-glow` fading to transparent,
  ellipse centered near the top of the viewport) layered under `body`, sitewide —
  raises perceived brightness/atmosphere without lightening the flat `--bg`/
  `--bg-raised`/`--surface` swatches or touching any text-contrast token. Most visible
  behind the hero, subtler everywhere else. Chosen over literally lightening `--bg`
  because that would shrink the yellow-accent contrast margin; this way the accent and
  text tokens never move.
- `image-rendering: pixelated` on any pixel-art imagery.
- Selection color: yellow bg, dark text (`::selection`).
- All motion honors `@media (prefers-reduced-motion: reduce)` — disable parallax and
  transitions.

## 5. Build order (this is the decided sequence)

Rationale: styling first because everything inherits it; docs before the bot because the
bot answers *from* the docs; agent desk last because it consumes chat + tickets.

1. **Phase 0 — Foundation** (plan 01): design tokens, fonts, root layout with widget
   slot, route renames/redirects.
2. **Phase 1 — Portfolio landing** (plan 01): hero + parallax, scrollspy sticky nav,
   sections, resume link, mobile behavior.
3. **Phase 2 — DylanDocs** (plan 02): frontmatter-aware loader, real markdown rendering,
   docs UI, all content files about Dylan.
4. **Phase 3 — DylanBot** (plan 02): persona rewrite, page-aware context, doc-link
   answers, persistent floating widget on every page.
5. **Phase 4 — DylanSupport** (plan 02): ticket states, level 1–3 auto-classification,
   agent expertise levels + urgent→L3 assignment, simulated email, live chat takeover.
6. **Phase 5 — Polish & verify** (plan 02): mobile pass, a11y pass, seeds, README
   rewrite, full demo script walkthrough.

## 6. Decisions log (answers to open questions)

- **Skills inside About or separate?** Inside About as a visually distinct "skills grid"
  subsection on the portfolio (compact, scannable). The *deep* version — proficiency
  detail, tooling, war stories — lives in DylanDocs (`/docs/skills-*`), and the About
  section links to it. Best of both: recruiters skim the grid, curious people go deep.
- **Docusaurus?** No. The existing KB loader + a markdown renderer (`mdex` or `earmark`)
  gives a real docs experience inside the one app. Docusaurus would fracture styling and
  break the persistent widget.
- **Is Ollama enough for a page-aware bot?** Yes. Page awareness is prompt engineering,
  not model capability: the widget knows the current route and injects a per-page context
  block (what this page is, what you can do here) into the system prompt. llama3.2
  handles that fine, and the deterministic fallback keeps demos alive when Ollama is off.
  The AI client stays behind one module boundary (`SupportBot.AI.Client`) so swapping to
  a hosted API later is a config change, not a rewrite.
- **No real email, ever.** The "send email" flow writes a simulated outbound email record
  to the ticket timeline with a visible "SIMULATED — not delivered" badge. No SMTP
  dependency is added. This is a hard requirement.
- **Elixir/Phoenix emphasis: dial it back.** Dylan is still building expertise in
  Elixir/Phoenix even though it's this platform's own implementation language. Don't
  let the skills grid (Plan 01 §1.2) or DylanDocs skills pages (Plan 02 §2.2) lead with
  it as a headline strength — order more established languages/frameworks first, and
  frame Elixir/Phoenix as "currently leveling up in, learned by building this platform"
  rather than claimed mastery. The colophon doc is the natural place to be candid about
  this; it reads as growth-minded, not as a weakness.

## 7. Content Dylan must supply (Claude Code: scaffold with `TODO(dylan)` placeholders where missing)

- Short bio + longer bio, headshot or pixel avatar
- Skills list grouped (languages, frameworks, tools) with rough proficiency
- 3–6 portfolio projects: name, one-liner, stack, links, 1 image each
- `resume.pdf`
- DylanDocs personal content: achievements, work history, hobbies/personal life,
  fun facts, "uses" (setup/gear) — anything beyond resume depth
