# 03 — Publishing plan

How to get SupportBot (the DylanDocs / DylanBot / DylanSupport portfolio) onto the public
internet at **dylanglover.com**. This file is the *decision* layer — which host, which
dependencies, and *why*. The step-by-step runbook for the chosen host already lives in
[`../DEPLOY.md`](../DEPLOY.md); this doc does not repeat those commands, it explains the
trade that led there and what's left to do.

Status as of 2026-07-17: the app builds a prod release cleanly (`MIX_ENV=prod mix release`
verified), `config/prod.exs` + `config/runtime.exs` are wired for a reverse proxy, and
`deploy/` ships a systemd unit, a Caddyfile, and `env.example`. **Nothing has been
provisioned yet** — provisioning costs money and needs a live Azure login. Publishing is
the last open item in the portfolio pivot (that, plus filling the `TODO(dylan)` content).

---

## 1. What "publishing" requires for this app

This is a stateful Phoenix/LiveView app, not a static site — so the host has to give us
four things, and every option below is judged on how cheaply and simply it delivers them:

1. **A long-running BEAM process** — LiveView holds a persistent WebSocket per visitor;
   there's no serverless/edge-function shortcut. Rules out Vercel/Netlify/GitHub Pages
   outright.
2. **A Postgres database** — conversations, tickets, agents, events all persist
   (`ecto_sql` + `postgrex`). Needs either a managed DB or one we run ourselves.
3. **TLS + a custom domain** — `dylanglover.com` on HTTPS. `runtime.exs` already supports
   `force_ssl` behind a proxy, so the host just needs to terminate TLS and forward.
4. **A secret store** — `SECRET_KEY_BASE`, `DATABASE_URL`, and (if we turn on live AI)
   `ANTHROPIC_API_KEY`. Never committed; injected as env at boot.

What it explicitly does **not** need (MVP constraints, carried from `00-OVERVIEW.md` and
the brief): no mailer/SMTP, no vector DB, no object storage, no CI/CD, no container
registry, no autoscaling. Keeping the requirement list this short is what lets the cheap
single-box option win.

---

## 2. Dependencies

### 2.1 Application dependencies (already in `mix.exs`, all release-safe)

Nothing here needs to change to publish — listed so the deploy target's build step is
predictable:

| Dep | Role at publish time |
|---|---|
| `phoenix` / `phoenix_live_view` / `phoenix_html` | The app + persistent WebSocket UI |
| `bandit` | HTTP server the release listens on (behind the proxy) |
| `ecto_sql` + `postgrex` | Talks to Postgres via `DATABASE_URL` |
| `phoenix_ecto` | Ecto ↔ Phoenix glue |
| `esbuild` (`runtime: dev only`) | Builds JS; `mix assets.deploy` runs it at build, not runtime |
| `req` | The only outbound HTTP client — used by `AI.Client` for Ollama/Claude |
| `mdex` | Renders the Markdown KB pages |
| `jason` | JSON |
| `phoenix_live_dashboard` + `telemetry_*` | `/dev/dashboard` metrics (guard in prod) |
| `dns_cluster` | BEAM clustering — inert on a single node, harmless to keep |

**Hard constraint (do not violate when publishing):** never add a mailer/SMTP dep
(Swoosh, Bamboo) or an embeddings/vector dep. Simulated email stays a `ticket_reply`
timeline entry. This is a plan-level rule, not a current gap — see `CLAUDE.md`.

### 2.2 Build-time / release tooling

- **Elixir ~> 1.15 + a matching Erlang/OTP** on the build machine.
- `mix assets.deploy` (esbuild --minify + `phx.digest`) before `mix release`.
- `lib/support_bot/release.ex` — runs migrations/seeds at runtime (`bin/support_bot eval
  "SupportBot.Release.migrate()"`), since a release has no Mix. This is what makes the app
  deployable *without* a Mix environment on the server.

### 2.3 Runtime infrastructure (host-provided, varies by option in §3)

Postgres 14+ · a TLS-terminating reverse proxy (or the platform's built-in TLS) · a place
to hold secrets · a process supervisor that restarts the release on crash/reboot.

### 2.4 The AI dependency (orthogonal to hosting)

DylanBot's "brain" is a separate decision from where we host — decided in
[`../DEPLOY.md` §7–8](../DEPLOY.md). **Decided and wired:** prod runs the **Claude API**
(Haiku 4.5) via `ANTHROPIC_API_KEY`; `AI.Client.chat/4` dispatches on `LLM_PROVIDER`
(`anthropic` | `ollama` | `fallback`) and keeps Ollama as the *local dev* adapter. A
deterministic, KB-grounded fallback covers any failed live call, so `LLM_PROVIDER=fallback`
is always available as a $0/no-key escape hatch. **Do not self-host Ollama in prod** on any
cheap box — `llama3.2` needs RAM the cheap tiers don't have. This choice is host-independent,
so it doesn't affect §3.

---

## 3. Hosting options — the comparison and the reason for the pick

All four below can satisfy §1. They differ on cost, how much ops we own, and how Elixir-
native they are.

### Option A — Single Azure VM + self-hosted Postgres + Caddy  ✅ CHOSEN

One B1s (1 vCPU/1 GB + 2 GB swap) or B2s (2 vCPU/4 GB) Ubuntu box running Postgres and the
Elixir release under systemd, with Caddy in front for automatic Let's Encrypt TLS. Full
runbook: [`../DEPLOY.md`](../DEPLOY.md).

- **Cost:** ~$7–9/mo (B1s) or ~$30–35/mo (B2s). Fits inside the **Azure for Students $100
  credit** — a year on B1s, several months on B2s.
- **Why it wins for *this* project:** the deciding factor is the Azure student credit —
  free hosting we already have access to beats paying anyone. dylanglover.com is a low-
  traffic portfolio; one box is genuinely enough, and owning the whole box is itself a
  portfolio artifact (systemd + Caddy + `pg_dump` cron is a story a support/infra role
  wants to see). Deps stay minimal: no managed-DB bill, no platform lock-in.
- **What we accept:** manual deploys (git pull + `mix release` + `systemctl restart`, §6 of
  DEPLOY.md), we own Postgres backups (`pg_dump` on cron), brief downtime on restart, and
  single-node (no HA). All fine for a personal site.

### Option B — Fly.io

Elixir-first PaaS; `fly launch` detects Phoenix, provisions a Fly Postgres, does rolling
deploys and TLS for you, and clustering "just works."

- **Cost:** small apps often land in/near the free-ish allowance; a always-on machine +
  Postgres is a few $/mo, but it's a *new* bill, not covered by the Azure credit.
- **Why not (for now):** it's the strongest technical runner-up and the best answer if we
  ever want zero-downtime deploys or multi-region without ops work. We're passing only
  because the Azure credit makes Option A effectively free and we want the hand-rolled-
  infra story. **This is the documented fallback** if the VM becomes annoying to babysit.

### Option C — Gigalixir

Elixir/Phoenix-specialized PaaS with `git push` deploys, hot upgrades, and managed
Postgres.

- **Why not:** smallest niche/community of the options and a separate bill; its headline
  features (hot upgrades, IEx-into-prod) are overkill for a portfolio. No advantage over B
  that matters here.

### Option D — Render / Railway

General PaaS with Elixir buildpacks/Dockerfiles and managed Postgres, `git`-triggered
deploys, automatic TLS.

- **Why not:** perfectly capable, but managed Postgres pushes past the always-free tier and
  it's yet another bill outside the Azure credit. No Elixir-specific edge over B.

**Decision:** **Option A (Azure VM)** because the Azure student credit zeroes the cost and
the owned-box ops is a deliberate portfolio signal. **Option B (Fly.io)** is the named
fallback if single-box maintenance stops being worth it. Both keep the exact same release
artifact and the same `env` contract, so switching later is a redeploy, not a rewrite.

---

## 4. Go-live checklist (Azure path)

Execution detail is in DEPLOY.md; this is the ordered gate list to actually launch.

- [ ] **Content freeze:** resolve the `TODO(dylan)` placeholders in the 6 KB pages + home
      before the site is public (this is the *other* open pivot item — don't launch with
      lorem/TODO copy).
- [x] **AI-copy honesty:** visitor-facing "powered by Ollama" strings updated to match what
      prod serves (Claude API in prod, Ollama in dev). Files listed in DEPLOY.md §8.
- [ ] Provision the VM + open ports 80/443 (DEPLOY.md §1).
- [ ] Point `dylanglover.com` / `www` A-records at the VM IP; wait for propagation
      (DEPLOY.md §2) — Caddy can't issue a cert until DNS resolves.
- [ ] VM base setup: Postgres, Erlang/Elixir, Caddy, swap (DEPLOY.md §3).
- [ ] Build + place the release; fill `/opt/support_bot/.env` with a real
      `SECRET_KEY_BASE` (`mix phx.gen.secret`) and `DATABASE_URL` (DEPLOY.md §4).
- [ ] Run migrations + first-time seeds via `SupportBot.Release` (DEPLOY.md §4).
- [ ] Enable systemd unit + Caddy; confirm `curl -I https://dylanglover.com` is 200/TLS
      (DEPLOY.md §5).
- [ ] Set `LLM_PROVIDER=anthropic` + a real `ANTHROPIC_API_KEY` in `.env` (the `AI.Client`
      code is already wired — DEPLOY.md §7). Or `LLM_PROVIDER=fallback` to launch key-free.
- [ ] Smoke test in a browser: chat widget answers, a chat escalates to a ticket, ticket
      shows in `/support`, `/docs` renders. Confirm the widget status dot shows the expected
      brain (green/live when Claude is configured, fallback otherwise).

---

## 5. Post-launch / operational plan

Deliberately minimal — these are the only ongoing chores Option A creates:

- **Backups (do own this):** `pg_dump` on a daily cron off-box or to a second disk. The one
  piece of self-hosting we can't hand-wave, since there's no managed DB doing it for us.
- **Redeploys:** manual, DEPLOY.md §6. Worth wrapping in a small shell script once the
  by-hand version gets old — not built yet.
- **Logs / health:** `journalctl -u support_bot -f`; the existing `/status` page is the
  visitor-facing health surface.
- **Cost watch:** keep an eye on the Azure credit burn-down, especially on B2s.

## 6. What we're intentionally *not* building for launch

No CI/CD, no managed Postgres, no Ollama in prod, no zero-downtime deploys, no autoscaling,
no CDN, no mailer. Every one of these is a reasonable skip for a low-traffic personal site;
each maps to a §3 upgrade (mostly "move to Fly.io") if traffic ever justifies it. Revisit
only when the single-box assumption stops holding.
