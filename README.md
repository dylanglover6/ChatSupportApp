# Dylan Glover — Portfolio Platform

This is Dylan Glover's personal portfolio site **and** the flagship project it showcases,
served from one Phoenix/LiveView application. Visitors land on a dark, pixel-accented
portfolio page, browse **DylanDocs** (documentation about Dylan — skills, projects, career,
personal), chat with **DylanBot** (a page-aware assistant grounded in those docs) from any
page, and — behind the scenes — **DylanSupport** is a working mock support-desk that
triages, classifies, and assigns whatever DylanBot can't resolve to a mock agent, live.

The interesting part: the support desk isn't a mockup bolted on for show. It's a real
Phoenix/LiveView/PubSub system — local keyword search standing in for RAG, a configurable
model provider (local Ollama in dev, Claude in prod) behind one boundary module with a
deterministic offline fallback, rule-based ticket classification and routing, and a
live chat takeover between an agent view and a visitor's chat widget over two browser
windows. It's both a portfolio page and a demo of how Dylan builds things.

## What's here

| Surface | Route | What it is |
|---|---|---|
| Portfolio landing | `/` | Hero, about/skills, projects, resume link, DylanDocs teaser, contact |
| DylanDocs | `/docs`, `/docs/:slug` | Docs about Dylan — skills, projects, career, personal, meta — rendered from Markdown with real frontmatter, categories, and search |
| DylanBot | every page (floating widget) + `/chat` | Page-aware chat assistant grounded in DylanDocs, backed by a configurable model provider (local Ollama in dev, Claude in prod) with an offline fallback |
| DylanSupport | `/support`, `/support/:id` | The mock agent desk: ticket queue, agent roster, auto-classification/assignment, ticket lifecycle, simulated outbound email, and live chat takeover |

`/kb` and `/tickets` (the app's original FlowDesk-era routes) permanently redirect to
`/docs` and `/support`.

## Architecture

One Phoenix app, four Ecto-backed contexts under `lib/support_bot/`, wired together by
`Tickets`:

```
                      ┌────────────────────┐
  visitor ── chats ──▶│   Chat / WidgetLive │◀── page-aware context ── PageContext
                      │   & ChatLive        │
                      └─────────┬───────────┘
                                │ persists messages, broadcasts over
                                │ Phoenix PubSub ("conversation:<id>")
                                ▼
   priv/kb/*.md ──▶ KB.Loader/Search ──▶ AI.Client (Ollama / Claude / fallback)
                                │
                                │ visitor escalates ("leave a message")
                                ▼
                      ┌────────────────────┐
                      │      Tickets        │── classifies (category, priority,
                      │  (orchestration)     │   support level 1–3, urgent)
                      └─────────┬───────────┘
                                │ Assignment.assign/4 — expertise level,
                                │ specialty, workload, shift
                                ▼
                      ┌────────────────────┐
                      │       Agents         │  mock agents: shift, specialties,
                      └────────────────────┘  color, expertise level (L1–L3)

  DylanSupport agent view (TicketLive.Show) ◀── same PubSub topic ──▶ visitor's widget
  "Take Over Chat" silences DylanBot; "Hand Back to Bot" resumes it.
```

- **`SupportBot.KB`** — reads Markdown from `priv/kb/` at runtime (frontmatter: title,
  slug, category, order, summary), renders it with `mdex`, and does keyword search. No
  embeddings or vector DB — an intentionally simple RAG-style story.
- **`SupportBot.Chat`** — conversations and messages (`user`/`assistant`/`agent`/`system`
  roles), plus the Phoenix PubSub plumbing (`subscribe/1`, and a broadcast on every
  `add_message/4`) that powers live chat takeover.
- **`SupportBot.AI`** — the single boundary for all model calls: `chat/4` (provider chosen by
  `LLM_PROVIDER` — Ollama in dev, Claude in prod — with a deterministic fallback when the model
  is unreachable or over budget), `summarize_ticket/3`, `agent_assist/2`,
  and rule-based `detect_category/1`, `detect_priority/1`, `detect_support_level/1`.
- **`SupportBot.Agents`** — mock agents with `specialties`, `expertise_level` (1–3),
  `color`, and a shift window that handles overnight (cross-midnight) shifts.
- **`SupportBot.Tickets`** — ticket lifecycle (`New → Open → Resolved → Closed`, with
  auto-reopen on a new customer message), `Assignment.assign/4` (urgent tickets always
  route to an expertise-level-3 agent; otherwise the most qualified, least-loaded,
  on-shift specialist), simulated email, and the takeover handlers.

## Setup

Requires Elixir/Erlang, PostgreSQL, and Node.js.

```bash
mix setup        # deps, assets, db create + migrate + seed
mix phx.server    # http://localhost:4000
```

`mix setup` seeds four mock agents (with expertise levels and shift windows) and six
believable tickets spanning every status and level — including one urgent ticket already
routed to a level-3 agent — plus a sample DylanBot conversation, so the demo below works
immediately on a fresh clone.

Default dev DB credentials are in `config/dev.exs` (`postgres`/`postgres`,
`support_bot_dev`) — adjust if your local Postgres differs.

### Local AI (optional but recommended)

DylanBot calls a local [Ollama](https://ollama.com) instance:

```bash
ollama serve &
ollama pull llama3.2
```

Override the model with `OLLAMA_MODEL`. **Ollama is optional** — if it's unreachable,
`AI.Client` falls through to a deterministic, still-Dylan-flavored response, and the
widget's status dot switches from green to amber so it's obvious you're in fallback mode.
Nothing else in the demo depends on Ollama being up.

The provider is selected by `LLM_PROVIDER` (`ollama` by default; `anthropic` for a hosted
Claude model, which is what the production deploy uses; `fallback` to force the offline
response). The Claude path reads `ANTHROPIC_API_KEY` and is guarded by per-actor and global
daily budget caps that degrade to the same fallback once exceeded.

### Verify a change

```bash
mix compile --warnings-as-errors
mix test
mix phx.server
```

## Demo script

The guided path, in one browser unless noted:

1. **Landing (`/`)** — scroll through the hero, about/skills, and projects sections.
2. **DylanDocs (`/docs`)** — browse the category tree, try the search box.
3. **Ask DylanBot** — open the widget (bottom-right, any page). Ask "what are Dylan's
   skills?" — the answer is grounded in DylanDocs with a real `/docs/:slug` link. Ask
   "what can I do on this page?" on a couple of different routes — the answer changes
   because the bot is page-aware.
4. **Escalate to a ticket** — ask something DylanBot can't answer, or click "Leave a
   message for Dylan" in the widget. Fill in the mini form; a ticket is created,
   auto-classified (category, priority, support level 1–3), and auto-assigned to a mock
   agent.
5. **DylanSupport (`/support`)** — see the new ticket in the queue (urgent tickets pin to
   the top with a red badge), the agent roster with expertise-level dots, and the recent
   activity feed. Open the ticket (`/support/:id`) for the full picture: AI summary, the
   unified history timeline, status controls, and a manual reassign dropdown.
   *Privacy note:* the desk is public, but each visitor only sees the mock/seed tickets
   plus the tickets they themselves created — never another visitor's tickets or email.
6. **Live chat takeover — the flagship demo.** Open a **second browser window in the same
   browser session** (a normal new window/tab, *not* incognito — visibility is
   session-scoped, so your agent desk must share the session that created the ticket) to
   the widget or `/chat` as "the visitor," keeping the conversation from step 3–4 going. On
   the ticket page (first window), click **"Take Over Chat."** The visitor's widget shows a
   system line ("`<Agent>` from DylanSupport joined the chat") and DylanBot stops
   auto-responding. Type in the ticket page's live chat box — it appears in the visitor's
   widget in real time over Phoenix PubSub, and vice versa. Click **"Hand Back to Bot"** to
   end the takeover; DylanBot resumes.
7. **Simulated email** — back on the ticket page, "Send Email (Simulated)" opens a
   composer; sending it writes a `SIMULATED — NOT DELIVERED` timeline card and resolves
   the ticket. No SMTP dependency exists in this app — that's a hard constraint, not a gap.

## Design system — "Dark Arcade"

Every color is a CSS custom property in `priv/static/assets/app.css` (`--bg`, `--accent`
yellow, `--ok`/`--warn`/`--danger`/`--info`/`--purple` status colors) — nothing is
hardcoded in a template. Square corners everywhere except the widget FAB, 2px borders,
hard pixel text-shadows on headings, a subtle scanline/CRT-glow overlay, and a blinking
block cursor on the hero and widget input. Display type is **Press Start 2P** (headings,
badges, nav), **VT323** for larger stylized/terminal text, and **Inter** for all body copy
and docs content — pixel fonts are decoration, never body copy. All motion respects
`prefers-reduced-motion`.

## MVP constraints (intentional, not gaps)

No real authentication, no real email sending (simulated replies write a labeled timeline
entry — see `Tickets.add_reply/2`; **no mailer/SMTP dependency is ever added**), no
embeddings/vector DB, no complex SLA rules, no hosting/deployment setup. The AI client
sits behind one module boundary (`SupportBot.AI.Client`) so swapping to a hosted model
provider later is a config change, not a rewrite.

## Routes

```text
/                   portfolio landing
/docs               DylanDocs index (category tree, search)
/docs/:slug         a single doc
/chat               full-page DylanBot chat
/support            DylanSupport ticket queue + agent roster
/support/:id        ticket workspace
/resume.pdf         resume download

/kb, /kb/:slug      → redirect to /docs, /docs/:slug
/tickets, /tickets/:id → redirect to /support, /support/:id
```
