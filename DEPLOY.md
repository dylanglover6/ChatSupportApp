# Deploying to dylanglover.com (Azure, cheap-and-simple)

One small Azure VM running Postgres + this app's Elixir release under systemd, with
Caddy in front for automatic HTTPS. DylanBot's "brain" is a separate decision: by default
there is **no live LLM in production** and `AI.Client` runs its deterministic fallback, but
you can point it at a hosted model instead — see **§7 (Live LLM options)** and **§8
(Switching providers & the Ollama question)** below. The rest is the whole cost/complexity
tradeoff: one box, no managed database, no container registry, no CI.

Everything here is a runbook for *you* to run — none of it was executed on your behalf
(provisioning costs money and needs your Azure login).

## 0. What changed in the repo to make this possible

`config/prod.exs` didn't exist, and `config/config.exs` unconditionally
`import_config`s it — so `MIX_ENV=prod mix compile` (and therefore `mix release`) failed
outright before this. Added `config/prod.exs` (log level, static-asset cache manifest)
and taught `config/runtime.exs` about `PHX_HOST` and `force_ssl` behind a reverse proxy.
Verified locally: `MIX_ENV=prod mix release` now assembles and the resulting release
boots and serves real requests.

## 1. Provision the VM

**Recommended size: `Standard_B2ats_v2`** (2 vCPU / 1GB RAM, AMD/x86) + a 2GB swap file,
Ubuntu 24.04 LTS. The Azure for Students free tier covers **750 hrs/month each of B1s,
B2ats v2 (AMD/x86), and B2pts v2 (Arm)** — so B2ats v2 is free exactly like B1s, but it's
current-generation and far easier to actually provision. VM residuals (the Standard public
IP ~$4/mo, OS disk, egress) run ~$5–8/month against the $100 credit.

**Avoid the older `Standard_B1s`.** It's a previous-generation size with chronically
restricted capacity; on Azure for Students subscriptions it frequently fails provisioning
with `SkuNotAvailable` / capacity-restriction errors across *every* allowed region (the
student "allowed locations" policy typically permits only a handful — check yours with
`az policy assignment list --query "[?parameters.listOfAllowedLocations].parameters.listOfAllowedLocations.value" -o json`).
If B1s won't deploy, switch to `Standard_B2ats_v2`: same 1GB RAM (so keep the swapfile),
double the CPU for the one-time release compile, and no other runbook changes since it's
also x86. Don't substitute `Standard_B2pts_v2` — that one is Arm/aarch64 and would require
rebuilding the whole stack. If you want more RAM headroom and don't mind spending credit,
size up to **B2s (2 vCPU / 4GB)** (~$30–35/month), still fine on the credit for several
months.

```bash
az login
az group create --name dylanglover-rg --location eastus

az vm create \
  --resource-group dylanglover-rg \
  --name dylanglover-vm \
  --image Ubuntu2404 \
  --size Standard_B2ats_v2 \
  --admin-username dylan \
  --generate-ssh-keys \
  --public-ip-sku Standard

az vm open-port --resource-group dylanglover-rg --name dylanglover-vm --port 80 --priority 100
az vm open-port --resource-group dylanglover-rg --name dylanglover-vm --port 443 --priority 101
```

Note the public IP from the `az vm create` output (or `az vm list-ip-addresses`).

## 2. DNS

At your domain registrar for dylanglover.com, add:

```
A     @     <vm public ip>
A     www   <vm public ip>      (optional, or CNAME to @)
```

Let it propagate before step 5 (Caddy needs it resolvable to issue a cert).

## 3. VM base setup

SSH in (`ssh dylan@<vm ip>`), then:

```bash
sudo apt update && sudo apt install -y postgresql postgresql-contrib nodejs npm git curl build-essential

# swap — needed on B2ats_v2 or B1s (both are 1GB RAM)
sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Erlang — from Ubuntu's own repo (precompiled; no source build, which matters on
# the 1GB box). Do NOT use the Erlang Solutions apt repo / esl-erlang: it's
# unreliable on noble/24.04, and its `elixir` package is 1.14 (app needs ~> 1.15).
sudo apt install -y erlang unzip

# Elixir — official precompiled build, auto-matched to the installed OTP major.
# (Ubuntu's `elixir` apt package is 1.14, too old for the app's `~> 1.15`.)
OTP=$(erl -noshell -eval 'io:format("~s",[erlang:system_info(otp_release)]), halt().')
cd /tmp
curl -fL -o "elixir-otp-${OTP}.zip" "https://github.com/elixir-lang/elixir/releases/download/v1.16.3/elixir-otp-${OTP}.zip"
sudo rm -rf /opt/elixir && sudo mkdir -p /opt/elixir
sudo unzip -o "elixir-otp-${OTP}.zip" -d /opt/elixir
# symlink into /usr/local/bin so `mix` is on PATH for all users (incl. the build user)
sudo ln -sf /opt/elixir/bin/elixir /opt/elixir/bin/elixirc /opt/elixir/bin/mix /opt/elixir/bin/iex /usr/local/bin/
elixir --version   # confirm OTP + Elixir 1.16.3

mix local.hex --force && mix local.rebar --force

# Caddy
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update && sudo apt install -y caddy
```

```bash
sudo -u postgres createuser support_bot -P   # set a real password, save it
sudo -u postgres createdb support_bot_prod -O support_bot
```

## 4. Build and place the release

```bash
sudo useradd -r -m -d /opt/support_bot -s /bin/bash support_bot

# Clone AS support_bot. Its home (/opt/support_bot) is mode 0700, so your admin
# user can't `cd` into it — do all repo work as support_bot, not by cd-ing there first.
sudo -u support_bot git clone https://github.com/dylanglover6/ChatSupportApp.git /opt/support_bot/src

# install hex + rebar for the build user (mix is per-user; avoids a mid-build prompt)
sudo -u support_bot mix local.hex --force
sudo -u support_bot mix local.rebar --force

# Build — the `cd` lives INSIDE the support_bot shell (a `cd` as your admin user
# would fail with "Permission denied" on the 0700 home).
sudo -u support_bot bash -c '
  cd /opt/support_bot/src
  mix deps.get --only prod
  (cd assets && npm install)
  MIX_ENV=prod mix assets.deploy
  MIX_ENV=prod mix release --overwrite
'

sudo ln -sfn /opt/support_bot/src/_build/prod/rel/support_bot /opt/support_bot/current
```

Copy `deploy/env.example` to `/opt/support_bot/.env`, fill in real values (generate
`SECRET_KEY_BASE` with `MIX_ENV=prod mix phx.gen.secret` on the VM — the `MIX_ENV=prod`
matters, since only prod deps were fetched; plain `mix phx.gen.secret` fails on missing
dev deps. Or just `openssl rand -base64 64`), lock it down:

```bash
sudo cp /opt/support_bot/src/deploy/env.example /opt/support_bot/.env
sudo chown support_bot:support_bot /opt/support_bot/.env
sudo chmod 600 /opt/support_bot/.env
sudo -u support_bot vim /opt/support_bot/.env   # fill in SECRET_KEY_BASE, DATABASE_URL
```

Run migrations (and, first time only, seeds — `lib/support_bot/release.ex` has both;
releases have no Mix at runtime, so `mix ecto.migrate` isn't available, hence the
`eval`/`SupportBot.Release` indirection):

```bash
sudo -u support_bot bash -c '
  cd /opt/support_bot/current
  set -a; source /opt/support_bot/.env; set +a
  bin/support_bot eval "SupportBot.Release.migrate()"
  # Seeds simulate a chat (Chat.add_message → PubSub broadcast), so the app must be
  # STARTED, not just loaded. Plain eval "SupportBot.Release.seed()" fails with
  # "unknown registry: SupportBot.PubSub" — start the app first in the same eval:
  bin/support_bot eval "Application.ensure_all_started(:support_bot); SupportBot.Release.seed()"
'
```

## 5. systemd + Caddy

```bash
sudo cp /opt/support_bot/src/deploy/support_bot.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now support_bot

sudo cp /opt/support_bot/src/deploy/Caddyfile /etc/caddy/Caddyfile
sudo systemctl restart caddy
```

Caddy fetches a Let's Encrypt cert for dylanglover.com automatically on first request,
as long as DNS is already pointing at the VM.

```bash
curl -I https://dylanglover.com
sudo journalctl -u support_bot -f    # tail logs if something's off
```

## 6. Redeploying after a change

```bash
sudo -u support_bot bash -c '
  cd /opt/support_bot/src && git pull
  mix deps.get --only prod
  MIX_ENV=prod mix assets.deploy
  MIX_ENV=prod mix release --overwrite
'
sudo -u support_bot bash -c 'cd /opt/support_bot/current && set -a; source /opt/support_bot/.env; set +a; bin/support_bot eval "SupportBot.Release.migrate()"'
sudo systemctl restart support_bot
```

Worth scripting once you're tired of typing this by hand — not set up yet.

**Before each release, audit dependencies** for known CVEs — `mix_audit` is in
`mix.exs`, so run it from a dev checkout (it's a build-only dep, not fetched by
`--only prod`):

```bash
mix deps.audit   # fails/lists if any dependency has a known vulnerability
```

Other ops hardening already in place: the dedicated `support_bot` Postgres role owns
only its own DB (least privilege, §3); `debug_errors` is dev-only so prod never leaks
stack traces to visitors; and back up the DB with a `pg_dump` cron (see below) as
data-loss/ransomware insurance.

## 7. DylanBot's brain — live LLM options

`SupportBot.AI.Client` is the single boundary for every model call, and it already returns
a deterministic, KB-grounded **fallback** whenever the live call fails. So the site never
breaks no matter which option you pick — the only question is what answers DylanBot gives.
The status dot in the widget already shows which one served the reply (`:ollama`/live vs
`:fallback`).

| Option | Cost | What it takes | Notes |
|---|---|---|---|
| **A. No live LLM** | $0 | Set `LLM_PROVIDER=fallback` | Canned, KB-grounded answers via the fallback. Always works, zero latency risk, no API key. Fine for a portfolio; just not "real AI." |
| **B. Hosted Claude API** *(default — this is what ships)* | ~pennies/month at this traffic | An `ANTHROPIC_API_KEY` secret (`LLM_PROVIDER=anthropic`) | Real answers. Ships with **Claude Haiku 4.5** (~$1 in / $5 out per 1M tokens — verify current pricing); a handful of short chats is cents/month. |
| **C. Other hosted open-model API** (Groq, Together, OpenRouter, …) | cheap, pay-per-token | An API key + a small new adapter in `AI.Client` | Same integration shape as B; some (e.g. Groq) are very fast. Would slot in as a third `provider()` branch. |
| **D. Self-host Ollama on the VM** | "free" inference | A much bigger/GPU VM (`LLM_PROVIDER=ollama`) | The dev adapter, already in the code. Impractical on the B1s/B2s box — `llama3.2` needs RAM the cheap box doesn't have and CPU inference is slow (you saw ~4.5s just to cold-load locally). Only if you size way up. Not recommended for the cheap-and-simple path. |

**Recommendation:** ship with **B** (Claude Haiku) — it's wired and is the launch default;
fall back to **A** (`LLM_PROVIDER=fallback`) any time you want to run key-free.

### Wiring up Option B — already implemented

`AI.Client.chat/4` now dispatches on `LLM_PROVIDER` (`anthropic` | `ollama` | `fallback`),
keeping Ollama as the local-dev adapter and adding the Anthropic path alongside it. Elixir
has no official Anthropic SDK, so the hosted call is raw HTTP via `Req` — the same shape the
Ollama call uses (`https://api.anthropic.com/v1/messages`, `x-api-key` +
`anthropic-version: 2023-06-01` headers, system prompt in the top-level `system` field,
`messages` user/assistant only, required `max_tokens`, parse `body["content"] |>
List.first() |> Map.get("text")`). Any non-200/error still returns the deterministic
fallback, so the site never breaks if the key/budget/network is down. To go live, just set
the env vars — no code change:

```
# .env
LLM_PROVIDER=anthropic
ANTHROPIC_API_KEY=sk-ant-...
# ANTHROPIC_MODEL=claude-haiku-4-5   # optional override; this is the default
```

### Cost controls

Because the hosted provider bills per token, live model calls are budget-gated in
`AI.Client.chat/5`; over any limit it degrades to the deterministic fallback (free,
on-brand) instead of billing Claude:

- **Per-actor daily cap** — 100 live calls / actor / 24h (`RateLimiter` `:llm_daily`),
  where an actor is `visitor_id + client IP`. A single visitor can't sit under the
  30s burst limit and run up the bill all day.
- **Global daily ceiling** — 2,000 live calls / 24h across all actors
  (`RateLimiter` `:llm_global`). A hard backstop on the monthly bill even under a
  distributed flood. Tune both in `lib/support_bot/rate_limiter.ex` (`@limits`).
- **Bounded input** — visitor messages are capped at 2,000 chars before reaching the
  model (output is already capped at `@anthropic_max_tokens 1024`, history at 8 turns).

**Also set an Anthropic Console budget alert** (Console → Billing → usage limits) as a
belt-and-suspenders backstop *outside* the app, so a runaway is noticed even if the
in-app ceiling has a bug. The in-app caps and the Console alert are independent.

## 8. Switching providers & the Ollama question

**Should you remove the Ollama references if you switch providers? No — don't do a blanket
find-and-delete.** Both halves below are now **done** in the codebase; this section records
what was changed and why.

**Code — Ollama kept as the dev adapter, provider made configurable.** Ollama is genuinely
useful for *local dev*: free, offline, no API key, no per-token cost. `AI.Client.chat/4`
now selects the adapter from `LLM_PROVIDER` (`ollama` | `anthropic` | `fallback`), defaulting
to `ollama` in dev; prod sets `anthropic`. The Ollama-specific internals were generalized to
be provider-neutral: the live-answer status atom is `:live` (was `:ollama`),
`ollama_reachable?/0` → `llm_reachable?/0`, and the widget assign `@ollama_status` →
`@llm_status`.

**User-facing copy — updated to match what prod actually serves.** These strings used to say
or imply "powered by Ollama," which is misleading now that prod runs Claude. They now
describe reality ("Claude API in production, Ollama in local dev"):

- `lib/support_bot_web/controllers/page_html/home.html.heex` — footer (now "Built with
  Elixir & Phoenix LiveView")
- `priv/projects.exs` — the project card `stack` (now `"Claude API"`)
- `priv/kb/colophon.md`, `priv/kb/project-support-platform.md`,
  `priv/kb/skills-tooling.md`, `priv/kb/skills-support.md` — the model prose
- `priv/repo/seeds.exs` — the sample chat message

Rule of thumb (applied): **keep Ollama in code as the dev adapter, generalize the naming, and
rewrite only the visitor-facing copy** so a recruiter reading the live site sees an accurate
description of what's actually answering them.

## What you're intentionally not getting

No CI/CD (deploys are manual, above), no managed Postgres (self-hosted on the same box,
so back it up yourself — `pg_dump` on a cron is enough for a portfolio site), no Ollama
in production (DylanBot runs on the Claude API live, with the deterministic fallback as a
safety net), no zero-downtime deploys (`systemctl restart` drops connections briefly), no
autoscaling. All reasonable to skip for a low-traffic personal site; revisit if that stops
being true.
