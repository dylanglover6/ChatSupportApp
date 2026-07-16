---
title: This Platform (SupportBot → DylanDocs)
slug: project-support-platform
category: Projects
order: 1
summary: Architecture case study for the Phoenix/LiveView app you're using right now.
---

# This Platform

"You're looking at it." This portfolio site, DylanDocs, DylanBot, and DylanSupport are
all one Phoenix application —
[github.com/dylanglover6/ChatSupportApp](https://github.com/dylanglover6/ChatSupportApp).

## Why one app instead of three

A separate docs site or a separate chat service would fracture the design system and
make a persistent chat widget across every page much harder to pull off cleanly. One
Phoenix app, one root layout, one `app.css` — the whole thing (portfolio, docs, chat,
support desk) shares a single "Dark Arcade" design system and a single LiveView/PubSub
runtime.

## Architecture

- **KB / DylanDocs loader** — loads these exact Markdown docs from `priv/kb/` at
  runtime, parses simple frontmatter (`title`, `slug`, `category`, `order`, `summary`),
  renders CommonMark to HTML, and does keyword search over title/summary/body — no
  vector database, intentionally simple for an MVP.
- **Chat / AI** — persists conversations and calls a local Ollama model (`llama3.2`)
  through one client module boundary, with a deterministic fallback response whenever
  Ollama isn't running, so the demo never breaks just because a model isn't loaded.
- **Agents / Tickets** — mock support agents with shifts, specialties, and expertise
  levels; a rule-based assignment engine; and a fully simulated "send email" path with
  zero SMTP dependency (see the [colophon](/docs/colophon) for why that's a hard
  constraint, not a shortcut).
- **Live chat takeover** — Phoenix PubSub broadcasts an agent's messages into a
  visitor's chat widget in real time, and visitor replies back to the agent's screen,
  with no polling involved.

## Why local Ollama instead of a hosted API

Page-awareness and DylanDocs grounding are prompt engineering, not model capability —
a small local model is enough for a portfolio demo, and it means the whole thing runs
offline. The AI client is one module boundary, so swapping in a hosted API later is a
config change, not a rewrite.

> TODO(dylan): add anything you want to say about what was hardest to build, what
> you'd do differently, or what you're building next.
