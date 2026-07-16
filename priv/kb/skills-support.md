---
title: Support & Technical Skills
slug: skills-support
category: Skills
order: 1
summary: The core of what Dylan does — troubleshooting, documentation, implementation, demos, AI integration, and support tooling.
---

# Support & Technical Skills

This is the heart of it: 7+ years turning ambiguous, high-stakes customer problems into
reproducible bug reports, clean escalations, and durable documentation. The languages and
frameworks pages cover *how* things get built; this page covers the work that actually
fills most of Dylan's days.

## Troubleshooting technical issues

Root-cause analysis is the through-line of every role. In practice that means:

- **Log analysis and API-response inspection** — reading server and client logs, checking
  HTTP status codes and payloads, and following a failing request across the client/server
  boundary until the actual cause (not just the symptom) is clear.
- **Structured reproduction** — turning "it doesn't work" into exact, repeatable steps with
  observed vs. expected behavior, environment details, and supporting evidence.
- **Tier II/III escalations** — the issues that got past the first line: edge-case bugs,
  integration failures, authentication and webhook problems, environment-specific behavior.
- **Browser DevTools, remote sessions, and screen-shares** — debugging live in the
  customer's environment when logs alone don't tell the story.

Across enterprise SaaS support this held a 95%+ CSAT at 50+ tickets a week, with a
deliberate focus on *reducing repeat contacts* — fixing the class of problem, not just the
instance.

## Documentation writing

Good support scales through writing. Dylan has owned:

- **Customer-facing knowledge base articles** for recurring failure patterns — the kind
  that measurably cut inbound volume for known issues.
- **Internal runbooks and troubleshooting guides** that make resolutions repeatable and
  shorten new-hire ramp time.
- **Escalation packets and bug reports** written for Engineering: observed behavior,
  expected behavior, customer impact, environment, repro steps, and logs, all in one place.

This site's own [DylanDocs](/docs/introduction) is an extension of that instinct —
documentation as a first-class product surface, in Markdown, with real structure and
search.

## Implementation

Getting customers *live*, not just unblocked: supporting enterprise implementations across
REST API integrations, webhooks, account and system configuration, and HTML/CSS-based
publishing workflows — and translating between what a customer wants and what the product
actually does. See [Frameworks](/docs/skills-frameworks) and
[Tooling](/docs/skills-tooling) for the specifics.

## Product demonstrations

Explaining technical products to both developer and non-technical audiences: walking
customers through configuration and integration over screen-share, fielding technical
pre-sales and integration-scoping questions alongside Sales and Customer Success, and
generally being the person who can make a complex product make sense out loud.

## AI integrations

The newest and fastest-growing part of the toolkit — and the reason this platform exists.
Dylan has built LLM-assisted support tooling hands-on: RAG-style knowledge base search,
automatic ticket triage and categorization, and LLM-generated reply suggestions, wired to a
local Ollama model with a graceful deterministic fallback. It's support-domain AI built by
someone who actually knows the support domain. Full write-up in
[This Platform](/docs/project-support-platform).

## Support ticketing systems

Years of daily driving **Zendesk, Jira, and Salesforce** — triage, severity, escalation
workflows, SLA-minded communication — plus, now, having *built* one: DylanSupport (this
site's agent desk) implements auto-classification, expertise-based assignment, a full
ticket lifecycle, and live agent takeover. Knowing ticketing systems from both sides — as a
power user and as a builder — is a genuinely uncommon combination.
