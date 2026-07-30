---
title: Colophon
slug: colophon
category: Meta
order: 1
summary: How this site is built: stack, design system, and an honest note on where Elixir fits.
---

# Colophon

## Stack

Phoenix + LiveView, Ecto/PostgreSQL, vanilla JavaScript (no frontend framework), and the
Claude API for DylanBot in production (a local Ollama model in development). See
[This Platform](/docs/project-support-platform) for the full architecture writeup.

## Why Phoenix/LiveView for the live parts

The interactive pieces (the DylanBot chat widget, the live "thinking…" indicator, and
especially the agent **chat takeover**) are where choosing Elixir/Phoenix paid off:

- **LiveView** renders the UI on the server and pushes only diffs down a WebSocket, so the
  chat widget, ticket workspace, and support desk are fully interactive with almost no
  hand-written frontend state. The state lives in an Elixir process, not scattered across
  client-side JavaScript.
- **Phoenix PubSub** powers the live takeover: when an agent takes over a conversation, a
  single broadcast on `"conversation:<id>"` reaches both the visitor's widget and the
  agent's ticket page and re-renders them in real time, across two separate browser
  sessions, with no external message broker to run (PubSub ships inside the app's
  supervision tree).
- **The BEAM's process model** makes the slow LLM call cheap to handle: every connection is
  its own lightweight process, and each reply is generated in a separate task that messages
  back when it's done, so the socket stays responsive during the 15–20s wait instead of
  blocking. These processes are isolated, so one failing chat can't take the others down.

It's the kind of workload the BEAM was built for. Ericsson designed Erlang for telecom,
where you have lots of concurrent, long-lived, low-latency connections, so a
chat-and-ticketing app running on persistent sockets fits it well.

## Design system: "Dark Arcade"

A dark, high-contrast theme built on CSS custom properties: a near-black background, a
single yellow accent used sparingly, and status colors reserved for actual status
(ok/warn/danger/info). Two pixel display fonts (Press Start 2P for headings and nav,
VT323 for terminal-style copy) sit on top of Inter for body text. Pixel fonts are
decoration, never paragraph copy, so the docs stay readable. Square corners
everywhere, hard 3px pixel-shadow on headings, and every animated effect respects
`prefers-reduced-motion`.

## An honest note on Elixir and Phoenix

Picking Elixir/Phoenix was deliberate. Dylan wanted to learn a new language for this
build, and instead of reaching for a familiar stack, he went with one whose strengths in
soft real-time, concurrency, and WebSockets fit what a live chat-and-support tool needs.
So the site is what it looks like: a project he learned the stack by building, not a claim
to have known it beforehand. See [Languages](/docs/skills-languages) and
[Frameworks](/docs/skills-frameworks) for more on that.
