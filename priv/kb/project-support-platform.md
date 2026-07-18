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
- **Chat / AI** — persists conversations and calls an LLM through one client module
  boundary — the Claude API in production, a local Ollama model (`llama3.2`) in
  development — with a deterministic fallback response whenever the live call fails, so
  the site never breaks just because a model is unavailable.
- **Agents / Tickets** — mock support agents with shifts, specialties, and expertise
  levels; a rule-based assignment engine; and a fully simulated "send email" path with
  zero SMTP dependency (see the [colophon](/docs/colophon) for why that's a hard
  constraint, not a shortcut).
- **Live chat takeover** — Phoenix PubSub broadcasts an agent's messages into a
  visitor's chat widget in real time, and visitor replies back to the agent's screen,
  with no polling involved.

## One AI boundary, two providers

Page-awareness and DylanDocs grounding are prompt engineering, not model capability, so
the AI client is a single module boundary with the provider chosen by config
(`LLM_PROVIDER`). Production runs the hosted **Claude API** (Haiku — cheap and quick for a
portfolio's traffic); local development runs a small **Ollama** model (`llama3.2`), which
is free, offline, and needs no API key. Because both sit behind the same boundary,
switching providers is a config change, not a rewrite — and a deterministic, KB-grounded
fallback covers any case where the live call fails.

> TODO(dylan): add anything you want to say about what was hardest to build, what
> you'd do differently, or what you're building next.
