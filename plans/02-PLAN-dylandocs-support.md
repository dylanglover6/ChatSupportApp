# Plan 02 — DylanDocs, DylanBot & DylanSupport (Phases 2–5)

> **For Claude Code:** Prereqs: `00-OVERVIEW.md` read, Plan 01 (Phases 0–1) complete.
> This plan overhauls the FlowDesk-era SupportBot into a Dylan-focused system inside the
> same Phoenix app. Hard requirement carried throughout: **no real emails are ever sent —
> no SMTP/mailer dependency is added.**

---

## Phase 2 — DylanDocs (markdown docs about Dylan)

### 2.1 Upgrade the KB loader → docs loader

Files: `lib/support_bot/kb/loader.ex`, `lib/support_bot/kb/search.ex`.

- Extend the loader to parse YAML-style frontmatter:
  `title`, `slug`, `category`, `order`, `summary`. Categories drive the sidebar grouping;
  `order` sorts within a category.
- Add real markdown → HTML rendering with **`mdex`** (preferred, CommonMark + syntax
  highlighting) or `earmark` if mdex causes trouble. Render at load time, cache in the
  loaded struct. Sanitize/trust: content is repo-owned, no user input — raw render is fine.
- Keep `search.ex` keyword search working over the new structure (search title +
  summary + body). The bot reuses this in Phase 3.

### 2.2 Replace the content — delete FlowDesk, write Dylan

Delete every FlowDesk article in `priv/kb/`. Create the DylanDocs set (Claude Code:
write real structure and headings, fill personal facts as `TODO(dylan)` blockquotes):

| Category | Docs (slug) |
|---|---|
| Start Here | `introduction` (who Dylan is, how to use these docs, "ask DylanBot") |
| Skills | `skills-languages`, `skills-frameworks`, `skills-tooling` (per-skill depth: experience, projects used in, honest proficiency — see Overview §6 "Elixir/Phoenix emphasis": don't lead with it, frame as in-progress) |
| Projects | `project-support-platform` (this app — architecture case study incl. Ollama, PubSub takeover), one doc per additional project |
| Career | `work-history`, `achievements` (deeper than the resume allows) |
| Personal | `about-dylan` (hobbies, interests, personal life — the beyond-resume stuff), `uses` (hardware/software setup) |
| Meta | `colophon` (how this site is built, the design system) |

### 2.3 Docs UI

Files: `lib/support_bot_web/live/kb_live/index.ex`, `show.ex` (now routed at `/docs`).

- **Index** (`/docs`): docs-site layout — category-grouped link tree (this is the docs'
  own inner sidebar, distinct from the global site nav), landing content = the
  `introduction` doc. Search box wired to `search.ex` with live results.
- **Show** (`/docs/:slug`): rendered markdown with the Dark Arcade code-block styling
  (dark surface, yellow keyword accents), doc title in pixel font, category breadcrumb,
  prev/next links by category order, "Ask DylanBot about this page" hint near the top.
- Mobile: inner sidebar collapses to a `<details>` disclosure above content.

**Phase 2 acceptance criteria**

- [ ] `/docs` shows all categories/docs; search returns sensible hits.
- [ ] Every doc renders styled HTML (headings, lists, code blocks, links) — no raw markdown.
- [ ] Zero FlowDesk references remain anywhere (`grep -ri flowdesk` returns nothing).

---

## Phase 3 — DylanBot (persona, page-awareness, persistent widget)

### 3.1 Persona & prompt rewrite

File: `lib/support_bot/ai/prompts.ex`.

- Rewrite the system prompt: DylanBot is the friendly guide to Dylan's portfolio.
  It answers questions about Dylan (skills, projects, experience, personal interests)
  **grounded in DylanDocs snippets** provided in-context, links to relevant doc pages,
  explains what the current page is, and offers next actions. Tone: helpful, a little
  playful, matches the "Howdy" brand. It must decline to invent facts about Dylan not in
  the docs, and instead suggest opening a ticket ("leave a message for Dylan").
- Keep the existing KB-snippet injection flow (`search.ex` results into the prompt) —
  now it's DylanDocs snippets. Instruct the model to reference docs by slug in the form
  `[[slug]]`; post-process assistant messages to turn `[[slug]]` into `/docs/:slug`
  links (validate slug exists; drop the brackets otherwise). The existing per-message
  `sources` field keeps rendering source chips as a guaranteed fallback when the model
  doesn't emit links.
- Update `lib/support_bot/ai/client.ex` fallback responses to Dylan-flavored ones
  (so demos without Ollama still make sense).

### 3.2 Page-aware context

New file: `lib/support_bot/ai/page_context.ex`.

- A pure function `for_path(path)` → `%{name, description, actions}` for each route
  (`/`, `/docs`, `/docs/:slug` — include the doc's title/summary, `/support`,
  `/support/:id`, `/chat`). Inject this block into the system prompt so DylanBot can
  answer "what is this page?" and proactively offer page-specific actions
  ("You're reading the skills doc — want the related projects?").
- This is prompt engineering, not new model capability — llama3.2 via the existing
  Ollama client is sufficient (decision in overview §6).

### 3.3 Persistent chat widget (every page)

New file: `lib/support_bot_web/live/widget_live.ex` (+ replace the Phase 0 placeholder
in the root layout with `live_render(@conn, WidgetLive, session: %{"path" => @conn.request_path}, sticky: true)`).

- **Position:** fixed **bottom-right** FAB — matches the Phase 0 layout placeholder
  already in place, no repositioning needed. Rounded-square, yellow border, pixel chat
  glyph, subtle one-time glow pulse when idle. **Unread notification:** a small solid
  yellow badge (dot, or a number for 2+) pinned to the FAB's top-right corner whenever
  a message arrives while the panel is collapsed (e.g. an agent takeover message in
  Phase 4) — clears on open. Mobile: stays visible but smaller; never overlaps the
  hamburger or overlay menu.
- **Terminal / old-Steam-chat vibe:** lean into the retro-chat aesthetic already
  established by the scramble/scanline motifs rather than a modern rounded-bubble
  messenger look. Header is a slim utilitarian title bar (`DYLANBOT`, tiny pixel font)
  with a small round status dot reusing the existing `--ok` (green, Ollama reachable) /
  `--warn` (fallback mode) tokens — the one deliberate non-monochrome accent, matching
  old IM online/away indicators. Message text renders in **VT323** (not body Inter) for
  a console-log feel; messages are simple left/right-aligned rows separated by thin
  `--border` divider lines rather than rounded bubbles — square corners throughout, per
  the design system. Input field uses a blinking block-cursor caret, consistent with
  the hero. Timestamps, if shown, are small and muted like old chat logs.
- **Expanded panel:** ~360×520px (full-screen sheet on mobile): header as above,
  message list (reuse chat_live message rendering + AutoScroll hook from
  `assets/js/app.js`, restyled per the vibe above), input, and 3 suggestion chips seeded
  from the current page's context actions.
- Reuses `SupportBot.Chat` context: one persistent conversation (latest-or-new, existing
  behavior), so the widget and `/chat` share history. Panel open/closed state survives
  live navigation via the sticky LiveView; full page loads simply remount collapsed —
  acceptable for MVP.
- Widget footer: "Open full chat" (`/chat`) and "Browse DylanDocs" (`/docs`) links.
- Escalation path: the existing create-ticket modal flow from `chat_live.ex` gets a
  compact equivalent in the widget ("Leave a message for Dylan" button when the bot
  can't help) — this is what feeds DylanSupport.

**Phase 3 acceptance criteria**

- [ ] Widget FAB appears on `/`, `/docs/*`, `/support/*`, `/chat`; opens/closes; sends and receives messages.
- [ ] Ask "what can I do on this page?" on 3 different pages → 3 page-specific answers.
- [ ] Ask "what are Dylan's skills?" → grounded answer with working link(s) into `/docs/skills-*`.
- [ ] Stop Ollama → widget still responds via fallback and status dot shows fallback mode.
- [ ] Creating a ticket from the widget produces a ticket visible in `/support`.

---

## Phase 4 — DylanSupport (agent desk overhaul)

### 4.1 Data model changes (one migration)

New migration + schema updates:

- `agents`: add `expertise_level` (integer 1–3, default 1). Update
  `priv/repo/seeds.exs`: keep Maya/Jordan/Sofia/Marcus, assign levels so there's at
  least one L3 (e.g., Maya 3, Jordan 2, Sofia 2, Marcus 1) and set their specialties to
  Dylan-relevant topics (docs, projects, hiring, general).
- `tickets`: add `support_level` (integer 1–3, the auto-classified difficulty) and
  ensure `status` supports: `new` → `open` → `resolved` → `closed`, plus boolean-like
  `urgent` escalation flag (keep `urgent` orthogonal to status so an urgent ticket can
  still be open/resolved). Migrate any existing status values.
- `ticket_replies`: add `kind` field: `"note"` (internal), `"email"` (simulated
  outbound), `"chat"` (live takeover message).

### 4.2 Auto-classification & assignment

Files: `lib/support_bot/ai/client.ex`, `lib/support_bot/tickets/assignment.ex`,
`lib/support_bot/tickets.ex`.

- On ticket creation, extend the existing category/priority detection call to also
  return `support_level` 1–3 (prompt: L1 = general/FAQ, L2 = technical/project detail,
  L3 = urgent/complex/escalation). Keyword fallback when Ollama is offline
  (e.g., "urgent", "broken", "asap" → L3 + urgent).
- Assignment rules in `assignment.ex` (extend existing availability/specialty/workload
  logic): ticket assigned to an available agent with `expertise_level >= support_level`,
  lowest workload wins. **Urgent/escalated tickets always auto-assign to a level 3
  agent** (if none on shift, pick least-loaded L3 regardless of shift and surface an
  "off-shift assignment" timeline event).
- Escalation triggers: (a) classifier says urgent, (b) agent clicks "Escalate" on the
  ticket page, (c) customer uses the word — keep it simple, classifier-driven.
  Escalation re-runs assignment to an L3 agent and logs a timeline event.

### 4.3 Ticket lifecycle (states)

In `lib/support_bot/tickets.ex`:

- Ticket created → `new`. Agent opens/first responds → `open`.
- **Agent sends a reply (email-sim or chat) → status auto-moves to `resolved`**;
  a "Close ticket" button moves `resolved` → `closed`.
- **New customer message arrives on a `resolved`/`closed` ticket → reopens to `open`**
  with a "reopened" timeline event.
- Every transition writes a `ticket_event` so the history is complete.

### 4.4 DylanSupport UI

Files: `ticket_live/index.ex`, `ticket_live/show.ex` (routed at `/support`).

- **Index** (`/support`): rename UI to "DylanSupport". Queue grouped/sortable by status;
  urgent tickets pinned on top with a red pixel `URGENT` badge; each row shows
  support-level badge (`L1`–`L3`), assigned agent chip with their level (e.g.,
  `MAYA ■■■`), status badge, age. Agent overview cards show expertise level, on-shift
  status, open count. Recent activity feed stays.
- **Show** (`/support/:id`) — the ticket workspace, four blocks:
  1. **Header:** subject, status controls (Resolve / Close / Reopen / Escalate),
     level + urgent badges, assignee (with manual reassign dropdown).
  2. **Full ticket history:** unified chronological timeline of chatbot conversation,
     customer messages, agent replies, simulated emails, internal notes, and state-change
     events — visually distinguished by kind (notes on `--surface` with dashed border,
     emails styled like an email card with To/Subject header, chat like bubbles).
  3. **Send email (simulated):** button opens composer (to, subject prefilled, body);
     on send it creates a `ticket_replies` row with `kind: "email"`, renders in the
     timeline with a yellow `SIMULATED — NOT DELIVERED` badge, and triggers the
     `resolved` transition. **No mail library, no network call.**
  4. **Live chat takeover:** see 4.5.
  - Keep existing AI summary + agent-assist panels (re-prompt them for the Dylan
    context).

### 4.5 Live chat takeover (the flagship demo)

Mechanism: Phoenix PubSub (already in the supervision tree).

- Widget/chat LiveViews subscribe to `"conversation:#{id}"`. Ticket show subscribes too.
- Agent clicks **"Take over chat"** on a ticket linked to a conversation →
  broadcast `{:agent_joined, agent}`: the visitor's widget shows a system line
  ("Maya from DylanSupport joined the chat"), header swaps to the agent name, and
  **DylanBot stops auto-responding** (an `agent_active` flag on the conversation,
  checked before invoking `AI.Client`).
- Agent types in a chat box on the ticket page → broadcast → appears in the visitor's
  widget in real time (and persists as `kind: "chat"` replies). Visitor messages
  broadcast back to the ticket view.
- **"Hand back to bot"** button ends takeover (`{:agent_left}`), bot resumes.
- Demo path: two browser windows (one incognito as visitor) — this is the showpiece;
  document it in the README demo script.

**Phase 4 acceptance criteria**

- [ ] New ticket gets auto level L1–L3 + assignment respecting expertise; urgent test ticket lands on an L3 agent.
- [ ] Reply/simulated email → `resolved`; new customer message → back to `open`; Close works; every transition appears in the timeline.
- [ ] Simulated email shows the not-delivered badge; `mix.exs` gained no mailer dependency.
- [ ] Takeover round-trip works across two browser sessions in real time; bot stays silent during takeover and resumes after.

---

## Phase 5 — Polish & verification

- **Mobile pass:** every route at 320/375/768px — nav overlay, widget sheet, docs
  disclosure sidebar, ticket tables become stacked cards below 600px.
- **A11y pass:** focus visible everywhere, esc closes widget/overlay/modals, form labels,
  contrast check on all badge colors, `prefers-reduced-motion` respected.
- **Seeds:** `priv/repo/seeds.exs` seeds agents (with levels), 5–6 believable tickets
  across all states/levels (incl. one urgent assigned to L3), and a sample conversation —
  so a fresh `mix setup` demos everything instantly.
- **README rewrite:** this is now the portfolio platform's front door — what it is,
  architecture diagram, setup, **demo script** (the guided path: landing → docs → ask
  DylanBot → escalate to ticket → takeover in second window), and design-system notes.
- **Final verification:** run the full demo script start to finish; run
  `grep -ri flowdesk` (must be empty); confirm no real email pathway exists; confirm the
  app boots and demos with Ollama stopped.
