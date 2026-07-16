---
title: Colophon
slug: colophon
category: Meta
order: 1
summary: How this site is built — stack, design system, and an honest note on where Elixir fits.
---

# Colophon

## Stack

Phoenix + LiveView, Ecto/PostgreSQL, vanilla JavaScript (no frontend framework), and a
local Ollama model for DylanBot. See
[This Platform](/docs/project-support-platform) for the full architecture writeup.

## Design system — "Dark Arcade"

A dark, high-contrast theme built on CSS custom properties: a near-black background, a
single yellow accent used sparingly, and status colors reserved for actual status
(ok/warn/danger/info). Two pixel display fonts (Press Start 2P for headings and nav,
VT323 for terminal-style copy) sit on top of Inter for body text — pixel fonts are
decoration, never paragraph copy, so the docs stay readable. Square corners
everywhere, hard 3px pixel-shadow on headings, and every animated effect respects
`prefers-reduced-motion`.

## No real email, ever

The "send email" flow on the DylanSupport ticket desk writes a simulated outbound
email record to the ticket timeline with a visible "SIMULATED — NOT DELIVERED" badge.
No SMTP or mailer library is part of this codebase, on purpose — it's a hard
constraint, not a gap.

## An honest note on Elixir and Phoenix

This entire platform — the one you're reading these docs on — is also where Dylan is
actively leveling up in Elixir and Phoenix. It isn't presented here as a claim of prior
mastery; it's presented as the learning-by-shipping project it actually is. See
[Languages](/docs/skills-languages) and [Frameworks](/docs/skills-frameworks) for the
same framing.

> TODO(dylan): add anything else about the build process, tools used to design or
> build this site, or credits.
