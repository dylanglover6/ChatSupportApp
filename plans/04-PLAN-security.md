# 04 — Security & rate-limiting pass

A sketch for hardening the public site before/around launch. Scoped to a **single-VM,
no-auth portfolio** — the goal is "cheap, proportionate, degrade-don't-fail," not
enterprise defense-in-depth. Passes are ordered by priority; each notes the concrete
files/modules involved so it's ready to implement, not just aspirational.

## What's already in place (baseline)

Worth stating so we build on it instead of duplicating:

- **App-level rate limiter** — [`SupportBot.RateLimiter`](../lib/support_bot/rate_limiter.ex):
  an in-memory ETS fixed-window limiter, per actor per action. Current limits: `chat`
  12/30s, `ticket` 5/10min. Swept every 5 min, resets on restart (fine for one node).
- **Actor derivation** — [`SupportBotWeb.RateLimit`](../lib/support_bot_web/rate_limit.ex):
  actor = session `visitor_id` + best-effort client IP (first `x-forwarded-for` entry
  behind Caddy, else socket peer). Applied inside the `chat`/`create_ticket` LiveView
  event handlers.
- **Browser pipeline** ([`router.ex`](../lib/support_bot_web/router.ex)) — `fetch_session`,
  `put_visitor_id`, `protect_from_forgery` (CSRF), `put_secure_browser_headers`.
- **Transport** — `force_ssl` behind the reverse proxy + `PHX_HOST` (config/runtime.exs);
  Caddy terminates TLS.
- **Reduced attack surface by design** — no auth, no real email/SMTP, no external
  integrations, no file uploads (MVP constraints). Fewer moving parts to abuse.
- **Data hygiene** — the hourly `Cleanup` job prunes stale visitor rows.

The two biggest *new* facts that shape this plan: (1) **DylanBot now calls the paid Claude
API in prod**, so cost is an attack surface; (2) rate limiting today lives only inside two
LiveView handlers — raw HTTP and socket connects are unthrottled.

---

## Pass 1 — LLM cost & abuse containment  ⟵ do first

The chat limit (12/30s) caps bursts but not sustained spend. A determined visitor could sit
just under it and run up the Anthropic bill; a scripted client hitting the LiveView could do
worse. The deterministic fallback is the perfect "over the limit" target — degrade to it
instead of erroring.

- **Per-actor daily LLM cap.** Add a `llm_daily` action to `RateLimiter` (e.g. ~100 live
  calls/actor/day, 24h window). In `AI.Client.chat/4`, when the actor is over the daily cap,
  short-circuit to `fallback_response/2` (status `:fallback`) rather than calling Claude.
  On-brand and free.
- **Global daily spend ceiling.** A single global counter (all actors) that flips the whole
  site to fallback mode past a threshold — a hard backstop on the monthly bill even under a
  distributed flood. Mirrors the "daily spend ceiling" the unified plan already requires for
  PromptCoach.
- **Anthropic Console budget alert.** Belt-and-suspenders outside the app — set a billing
  alert on the Anthropic account so a runaway is noticed even if the in-app ceiling has a bug.
- **Bound the model input.** Cap chat message length (e.g. 2000 chars) and reject/trim empty
  or oversized messages before they reach `AI.Client`. History is already capped
  (`@history_window 8`) and output is capped (`@anthropic_max_tokens 1024`) — good; just add
  the input-size guard.

## Pass 2 — HTTP & connection-level rate limiting

Today's limits don't cover raw page loads, `/docs`, `/status/:token`, LiveView **mounts**,
or WebSocket reconnect storms — all of which a single B1s can be knocked over by.

- **Plug-level request throttle.** Add a `:request` action to `RateLimiter` and a thin plug
  in the `:browser` pipeline keyed on client IP (generous, e.g. 300/min) — cheap protection
  against a crawler or a small flood hammering HTML/asset routes. Reuses the existing ETS
  table; no new dependency.
- **Throttle LiveView connects.** Rate-limit socket **mounts** (not just in-session events)
  so reconnect loops can't spin up unbounded processes.
- **WebSocket origin check.** Set `check_origin` to the real host list in the prod endpoint
  socket config so other origins can't open LiveView sockets against the app.

## Pass 3 — Input validation & data hygiene

- **Validate ticket fields at the boundary.** The escalation form trusts client-side
  `required`. Add Ecto changeset validations on the ticket schema: `customer_email` format,
  and max lengths on `customer_name`/`customer_email`/`title`. Stops oversized/garbage rows.
- **Honeypot on the escalation form.** A hidden field bots fill and humans don't — silently
  drop submissions that populate it. Near-zero UX cost, no CAPTCHA. (The new disclaimer note
  also reduces genuine misdirected submissions.)
- **Confirm chat/ticket content is escaped, not raw HTML.** Visitor chat text and ticket
  fields are echoed back on the support desk and in the widget — verify they render as
  escaped text (HEEX does this by default) so a visitor can't stored-XSS the agent view.
  KB markdown is authored by Dylan (trusted); chat/ticket input is not.
- **PII posture.** Tickets persist visitor name/email in Postgres. Document that the Cleanup
  job prunes stale rows, nothing sensitive is stored, and the disclaimer sets expectations.

## Pass 4 — Headers, transport, secrets

- **Content-Security-Policy (biggest header gap).** `put_secure_browser_headers` sets
  `X-Frame-Options`/`X-Content-Type-Options` but no CSP. Add one: `default-src 'self'`,
  `connect-src 'self' wss:` (LiveView), `img-src 'self' data:`. The app inlines two tiny
  scripts (nav-collapsed pre-paint in `root.html.heex`, the hero subline in `home.html.heex`)
  — hash or nonce them, or move them into `app.js`, so the CSP can drop `'unsafe-inline'`.
- **HSTS in prod.** `force_ssl` is on; add `Strict-Transport-Security` (via the secure-headers
  config or in Caddy).
- **Secret handling.** `ANTHROPIC_API_KEY`, `SECRET_KEY_BASE`, `DATABASE_URL` all come from
  env (`.env` gitignored). Audit that `AI.Client` never logs the key or the full outbound
  request; scrub if needed. Keep the key out of every committed file.
- **Cookie flags.** Confirm the session cookie is `secure` + `http_only` + `same_site: Lax`
  in prod.

## Pass 5 — Dependencies & ops

- **Dependency audit.** Add `:mix_audit` and run `mix deps.audit` in the deploy checklist to
  catch known-vuln deps before each release.
- **Least-privilege DB.** The dedicated `support_bot` Postgres role should own only its own
  DB (already the case per DEPLOY.md).
- **No debug errors in prod.** Confirm `debug_errors: false` / no stack traces leak to
  visitors in prod (Phoenix default).
- **Backups.** The `pg_dump` cron from the publishing plan doubles as ransomware/data-loss
  insurance.

---

## Suggested order

1. **Pass 1** (LLM cost) — the one that costs real money if skipped; ship before sharing the
   URL widely.
2. **Pass 2** (connection throttle) + **Pass 4 CSP** — the load-bearing hardening.
3. **Pass 3** (validation/honeypot) — quick wins, low risk.
4. **Pass 5** (audit/ops) — fold into the deploy runbook.

## Out of scope (deliberate, for a portfolio)

No user accounts/auth, no WAF, no CAPTCHA, no bot-detection service, no distributed/Redis
rate limiter (single node makes the ETS limiter sufficient), no secrets manager beyond the
VM `.env`. Each maps to an obvious upgrade if this ever becomes higher-traffic or multi-node
— revisit then.
