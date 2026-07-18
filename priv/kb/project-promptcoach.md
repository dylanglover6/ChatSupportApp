---
title: PromptCoach
slug: project-promptcoach
category: Projects
order: 3
summary: An AI coaching tool that scores, explains, and rewrites your prompts.
---

# PromptCoach

**A full-stack, AI-powered coaching tool that helps people write better prompts.**

Most people writing prompts for AI tools never get feedback on *why* a prompt worked or
didn't — they just see the output and guess. PromptCoach closes that loop. Paste a prompt
in, and it's scored against a real rubric, explained in plain language, and rewritten to
fix its specific weaknesses. Beyond one-off feedback, it includes a Learn section teaching
the underlying principles and a Practice mode with a bank of realistic scenarios to apply
them against — turning prompt engineering from guesswork into a skill you can deliberately
practice and measure.

## What it does

- **Rate my prompt** — paste any prompt and get an instant, structured evaluation: a
  weighted 100-point score, a plain-language verdict, and a rewritten version that
  addresses the specific gaps found. If the prompt is too vague to evaluate honestly, it
  asks one clarifying question instead of guessing — and never asks twice.
- **Learn** — short, skimmable lessons, one per rubric concept, each with a real
  bad-prompt/good-prompt pair and a two-to-three sentence explanation of why the
  difference matters.
- **Practice** — a bank of ten realistic scenarios (data extraction, code generation,
  summarization, classification, and more) graded against that specific task's
  requirements, culminating in a deliberately underspecified "trap" scenario that tests
  whether you've internalized the habit of adding your own clarity — not just following
  instructions.

## Technology stack

| Layer | Choice | Why |
|---|---|---|
| Frontend | React (Vite) | Fast local dev, small production bundle, no framework overhead for a focused single-purpose app |
| Hosting | Azure Static Web Apps | Serves the frontend and links directly to a managed Functions backend — one deployment pipeline, near-zero idle cost |
| Backend | Azure Functions (Node.js) | Serverless HTTP endpoints; scales to zero when idle, scales out automatically under load |
| AI | Anthropic Claude API | Structured, tool-forced output (not fragile text parsing) drives every rating, so the frontend always gets predictable, typed JSON back |
| Auth | Azure Static Web Apps built-in auth (GitHub) | Zero custom auth code or session management — the platform handles the OAuth flow and identity headers natively |
| CI/CD | GitHub Actions (auto-provisioned by Azure) | Every push to `main` builds and deploys automatically |

## Engineering highlights

**A scoring rubric refined through empirical testing, not guesswork.** The rating system
went through several full iterations, each driven by deliberately adversarial test prompts
designed to expose specific failure modes — a prompt with genuinely conflicting
requirements, a prompt requiring clarification, a wall-of-text prompt with no visual
structure. Each round surfaced a real, specific miscalibration (scores that didn't match
their own written justification, a model second-guessing plainly-computed facts), which
was then fixed and re-verified against the exact prompt that exposed it — not just patched
and assumed fixed.

**Deterministic math where it matters.** The final score is a weighted combination of five
dimensions, but the weighting arithmetic happens in application code, never inside the AI's
own response — removing an entire category of run-to-run inconsistency that a
purely model-computed score would carry. The same principle applies to structural analysis
(line breaks, word count): those are computed directly from the text in code and handed to
the model as established facts, rather than trusting the model to notice formatting on its
own.

**One scoring engine, reused everywhere.** Practice mode's task-specific grading reuses the
exact same rubric and scoring pipeline as the general-purpose rater, rather than a second
parallel system — a task's specific requirements are folded into the same evaluation as
additional context, so scores stay directly comparable across every part of the app.

**Built with an AI-assisted engineering workflow.** PromptCoach itself was built in close
collaboration with Claude Code, with Dylan directing architecture decisions, designing and
iterating the scoring rubric, and verifying every change against a live, running instance
before considering it done — a fitting way to build a tool about writing better AI prompts.

## Status

Actively developed. Core features (rating, Learn, Practice mode, GitHub login) are live;
API rate limiting and cost-control infrastructure are in progress ahead of public launch.

---

_See also [this platform](/docs/project-support-platform) and
[Plot Twist](/docs/project-plot-twist)._
