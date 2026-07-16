# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

SupportBot is a Phoenix/LiveView portfolio MVP demonstrating an AI-powered support triage
platform ("FlowDesk"): a customer chats with an AI troubleshooting assistant that searches a
local Markdown knowledge base, escalates to a structured support ticket when it can't resolve
the issue, and the ticket is auto-classified and auto-assigned to a mock support agent based on
shift, specialty, workload, and team color. A manager dashboard shows agents and the ticket
queue; each ticket detail page shows chat history, AI summaries, KB sources, timeline, and
agent replies/notes.

**Read `plans/00-OVERVIEW.md` before making UI/branding changes.** There is an approved plan
(`plans/00-OVERVIEW.md` → `01-PLAN-portfolio.md` → `02-PLAN-dylandocs-support.md`) to evolve
this exact codebase in place into Dylan Glover's personal portfolio site: the FlowDesk
knowledge base becomes "DylanDocs" (content about Dylan), the chatbot becomes "DylanBot"
(page-aware, grounded in DylanDocs), and the manager dashboard becomes "DylanSupport" (with
expertise levels, urgent escalation to L3 agents, simulated outbound email, and live PubSub
chat takeover). The `SupportBot`/`support_bot_web` module namespace stays as-is — only
user-facing strings and routes get rebranded. If asked to work on portfolio/docs/branding
features, those plan files are the source of truth for design tokens, route map, and build
order, not the current FlowDesk content described above.

## Commands

```powershell
# Install deps, set up assets, create/migrate/seed the database
mix setup

# Run the dev server (http://localhost:4000)
mix phx.server
# or, inside IEx:
iex -S mix phx.server

# Format code (import_deps: ecto, ecto_sql, phoenix; also formats .heex)
mix format

# Reset the local database (drop, create, migrate, seed)
mix ecto.reset

# Run a single migration file manually if needed
mix ecto.migrate
```

### Verify a change

```powershell
mix compile --warnings-as-errors
mix test
mix phx.server
```

There is no `test/` directory and no tests currently exist in this repo, despite `mix.exs`
defining a `test` alias (`ecto.create --quiet`, `ecto.migrate --quiet`, `test`) that assumes
`MIX_ENV=test` database setup. If adding tests, they'll need `test/support/` scaffolding
(ExUnit case templates, `DataCase`/`ConnCase`) since `elixirc_paths(:test)` already includes
`test/support`.

### Local AI dependency

The AI client (`lib/support_bot/ai/client.ex`) calls Ollama at
`http://localhost:11434/api/chat` with model `llama3.2` (override via `OLLAMA_MODEL` env var).
If Ollama is not running, `chat/4` falls through to a deterministic canned response so the app
and its demo flow still work without a live model — keep this fallback behavior when touching
the AI client.

### Database

Dev Postgres defaults live in `config/dev.exs` (`postgres`/`postgres`, db
`support_bot_dev`). Prod config (`config/runtime.exs`) requires `DATABASE_URL` and
`SECRET_KEY_BASE` env vars. There is a single squashed migration:
`priv/repo/migrations/20260616182000_create_support_bot_tables.exs`. Seed data (mock agents,
demo tickets) lives in `priv/repo/seeds.exs` and is run automatically by `mix setup` /
`ecto.setup`.

## Architecture

Standard Phoenix context structure under `lib/support_bot/` (business logic, Ecto) and
`lib/support_bot_web/` (LiveViews, router, components). Four contexts, wired together by
`SupportBot.Tickets`:

- **`SupportBot.KB`** (`kb/loader.ex`, `kb/search.ex`) — reads Markdown files from `priv/kb/`
  at runtime, extracts title/slug/body, and does keyword-based scoring/search (no embeddings,
  no vector DB — intentionally simple "RAG-style" story). Powers both the `/kb` browser and the
  chat's context injection.
- **`SupportBot.Chat`** (`chat.ex`, `chat/conversation.ex`, `chat/message.ex`) — persists
  conversations and messages (`role`: user/assistant/system) with the KB sources used for that
  turn. `ChatLive` (`live/chat_live.ex`) is the `/chat` page: on each user message it calls
  `KB.Search`, then `AI.Client.chat/4` with history + KB snippets, then persists both messages.
- **`SupportBot.AI`** (`ai/client.ex`, `ai/prompts.ex`) — single boundary module for all model
  calls: general `chat/4`, `summarize_ticket/3` (turns a conversation into ticket fields),
  `agent_assist/2` (suggested reply/next-step/escalation for the agent view), plus rule-based
  `detect_category/1` and `detect_priority/1` used both by summarization and as an offline
  fallback. Keep new AI-provider logic behind this module so swapping providers later
  (OpenAI/Anthropic per the brief) is a config change, not a rewrite.
- **`SupportBot.Agents`** (`agents.ex`, `agents/agent.ex`, `agents/schedule.ex`) — mock agents
  with `specialties`, `color`, and a `shift_start`/`shift_end` (`Time`). `Schedule.available?/2`
  handles overnight shifts that cross midnight.
- **`SupportBot.Tickets`** (`tickets.ex`, `tickets/ticket.ex`, `tickets/ticket_event.ex`,
  `tickets/ticket_reply.ex`, `tickets/assignment.ex`) — the orchestration layer (DylanSupport,
  Phase 4):
  - `create_from_conversation/3` pulls the chat history, calls `AI.Client.summarize_ticket/3`
    for category/priority/support_level/urgent/summary fields, calls `Assignment.assign/4`, and
    inserts the ticket + `ticket_created`/`ticket_assigned` (+ `off_shift_assignment` if
    applicable) events in one transaction.
  - `Assignment.assign/4` (`tickets/assignment.ex`) takes `(category, support_level, urgent,
    current_time \\ Time.utc_now())`. Urgent tickets always route to an on-shift expertise-level-3
    agent, or the least-loaded L3 agent off-shift (ticket marked `"Waiting for Agent"`, logs
    `off_shift_assignment`). Non-urgent tickets prefer an on-shift agent who specializes in the
    category and whose `expertise_level >= support_level`, then any qualified on-shift agent, then
    any on-shift agent, then whoever's shift starts soonest. Open-ticket counts exclude
    `"Resolved"`/`"Closed"` tickets.
  - Lifecycle: `open_ticket/1` (New → Open, called on ticket-page mount), `resolve_ticket/1`,
    `close_ticket/1` (Resolved → Closed), `reopen_ticket/1`, `escalate_ticket/1` (forces urgent +
    reassigns to an L3 agent), `reassign_ticket/2` (manual), `maybe_reopen_for_conversation/1`
    (reopens any Resolved/Closed ticket when the linked conversation gets a new customer message —
    called from `chat_live.ex`/`widget_live.ex` after every user message).
  - `add_reply/2` inserts a `ticket_reply` (`kind`: `"note"` | `"email"` | `"chat"`) and logs a
    `ticket_event`. `"email"` and `"chat"` replies auto-transition the ticket to `"Resolved"`;
    `"chat"` replies also insert a `SupportBot.Chat` message (`role: "agent"`) so they appear live
    in the visitor's widget. `"note"` replies (internal) never change status.
  - `take_over_chat/1` / `hand_back_chat/1` flip `conversations.agent_active` (via
    `SupportBot.Chat.set_agent_active/3`) and broadcast over Phoenix PubSub
    (`"conversation:#{id}"`) so the widget/chat LiveViews stop invoking `AI.Client` while an agent
    is live — see `SupportBot.Chat.subscribe/1`, `broadcast` payloads `{:new_message, message}`
    and `{:agent_status, active?, agent_name}`.
  - `generate_agent_assist/1` re-invokes the AI client and stores the result on the ticket.

LiveViews mirror this: `live/chat_live.ex` (`/chat`), `live/widget_live.ex` (persistent widget,
every page), `live/ticket_live/index.ex` (`/support`, DylanSupport queue: agent cards with
expertise-level dots, urgent-pinned ticket queue, recent activity from `ticket_events`),
`live/ticket_live/show.ex` (`/support/:id`, the ticket workspace: status controls, manual
reassign, unified history timeline, simulated email composer, live chat takeover panel),
`live/kb_live/index.ex` and `show.ex` (`/docs`, `/docs/:slug`). Routes are defined in
`lib/support_bot_web/router.ex`.

Statuses: `New`, `Open`, `Waiting for Agent`, `Resolved`, `Closed` (see `Ticket.statuses/0`).
`urgent` is a separate boolean field, orthogonal to status. Priorities: `Low`, `Normal`, `High`,
`Urgent` (from `AI.Client.detect_priority/1`, independent of `urgent`/`support_level`).
Support levels: `1`–`3` (from `AI.Client.detect_support_level/1`; `3` implies `urgent`).
Categories: `Docs`, `Projects`, `Hiring`, `General` — matched by regex in
`AI.Client.detect_category/1` and expected by `Assignment.assign/4` (agent `specialties`), so
keep them in sync if you add/rename a category.

## MVP constraints (still apply per the original brief, `supportbot_codex_brief.md`)

No real authentication, no real email sending, no external ticketing integrations, no
embeddings/vector DB, no complex SLA rules. The portfolio-pivot plan (see above) explicitly
carries forward "no real email, ever" — any "send email" feature must write a simulated,
clearly-labeled timeline entry rather than adding an SMTP/mailer dependency.

**Never add a mailer/SMTP dependency** (e.g. Swoosh, Bamboo) to `mix.exs` — this is a hard
constraint from the plan, not just a current gap. Simulated email is a `ticket_reply`/timeline
entry, not a real send.

**All colors come from the CSS tokens in `app.css`** (the "Dark Arcade" custom properties
defined in `plans/00-OVERVIEW.md` §4 — `--bg`, `--accent`, `--ok`/`--warn`/`--danger`, etc.).
Never hardcode a hex/rgb color in a `.heex` template or component — reference a token instead
so the design system stays consistent across the portfolio, docs, chat, and support desk.

The `hallmark` skill advises on execution quality only (spacing, hierarchy, typography scale,
contrast, motion); the design system in `plans/00-OVERVIEW.md` §4 is the source of truth for
colors, fonts, and theme. Don't let a hallmark suggestion override a Dark Arcade token.
