# Unified Deployment Plan — dylanglover.com (3 projects, Azure-first)

**Audience:** this document is shared across three repos. Each repo's Claude Code session
should read the **Shared architecture** section, then act only on its own project section.
Do not modify resources owned by another project except where explicitly instructed
(the Caddyfile, owned by the Portfolio repo, is the one shared file).

## Shared architecture

One Azure VM anchors everything. Plot Twist co-hosts on it; PromptCoach is the only
separately-hosted piece (Azure Static Web Apps).

```
dylanglover.com ────────────┐
www.dylanglover.com ────────┤        ┌──────────────────────────────────────┐
plottwist.dylanglover.com ──┼──A──▶  │  Azure VM (B1s, Ubuntu 24.04)         │
                            │        │   Caddy :443 (auto-HTTPS for all 3    │
                            │        │   hostnames)                          │
                            │        │    ├─▶ localhost — Phoenix release    │
                            │        │    │     (portfolio + DylanBot)       │
                            │        │    │     + Postgres (same box)        │
                            │        │    └─▶ localhost:3000 — Plot Twist    │
                            │        │          Express + built React SPA    │
                            │        └──────────────┬───────────────────────┘
                            │                       └─▶ MongoDB Atlas M0 (free)
                            │                       └─▶ Unsplash API
promptcoach.dylanglover.com ──CNAME──▶ Azure Static Web Apps (Free tier)
                                        frontend + managed Functions API
                                        + Table Storage (rate-limit counters)
                                        └─▶ Anthropic API
```

### Domains & DNS (registrar DNS — no Azure DNS zone)

All records are added in the registrar's DNS dashboard for dylanglover.com:

| Record | Host | Value | For |
|---|---|---|---|
| A | `@` | `<VM public IP>` | Portfolio |
| A | `www` | `<VM public IP>` | Portfolio (or CNAME → `@`) |
| A | `plottwist` | `<VM public IP>` | Plot Twist |
| CNAME | `promptcoach` | `<app>.azurestaticapps.net` | PromptCoach |
| TXT | (as prompted) | (validation token) | Only if SWA asks for domain validation |

The VM IP comes from the Portfolio provisioning step, so **Portfolio deploys first**.

### Budget (Azure for Students: $100 credit, 12 months, no credit card)

| Resource | Cost |
|---|---|
| B1s VM (750 hrs/mo) | **Free for 12 months** under the student plan (up to 2 instances; B1s specifically — B1ls is *not* free) |
| Static Web Apps Free tier | **Always free** (2 custom domains per app, free auto-renewing SSL, managed Functions included) |
| MongoDB Atlas M0 | **Free** (external to Azure) |
| Azure Table Storage (PromptCoach counters) | Pennies/month against credit |
| VM residuals: public IP (~$4/mo), OS disk, egress | Against the $100 credit — expect ~$5–8/mo total. Note the free tier covers a **P6 64GiB Premium SSD**; a default Standard SSD bills small amounts to credit. |
| Anthropic API (PromptCoach) | Separate — billed on the Anthropic account, not Azure |

**Everyone:** treat the $100 credit as the buffer for VM residuals and any temporary
resize. First deployer should create a **Cost Management budget alert** (e.g. alert at
$25/$50/$75 cumulative) — it's two minutes in the portal and a good resume habit.

**RAM caveat:** B1s is 1GB. Phoenix + Postgres + Node + Caddy fits for low traffic
**only with the 2GB swapfile** (Portfolio runbook §3 already includes it). If the box
thrashes, `az vm resize` to B2s (4GB, ~$30–35/mo from credit) temporarily, or move
Plot Twist off-box later. Don't pre-optimize; measure first.

### Launch order

1. **Portfolio** — provisions the VM (this produces the public IP), Caddy, Postgres,
   Phoenix release. Add all A records once the IP exists.
2. **Plot Twist** — deploys onto the same VM behind Caddy; needs Atlas + Unsplash keys.
3. **PromptCoach** — **blocked on rate limiting landing** (in progress). Provisioning
   the SWA resource early is fine, but no custom domain / no sharing the URL until the
   per-IP limits + spend ceiling are merged.

---

## Project 1: Portfolio (Phoenix/Elixir — `ChatSupportApp`)

Follow the existing `DEPLOY.md` runbook (§1–6) as written — it is still the source of
truth for provisioning, DNS for the apex, base setup, release build, systemd, and Caddy.
Changes and additions from this shared plan:

1. **The Caddyfile in `deploy/Caddyfile` becomes shared infrastructure.** Add a second
   site block so the same Caddy instance fronts Plot Twist:

   ```caddyfile
   plottwist.dylanglover.com {
       reverse_proxy localhost:3000
   }
   ```

   Keep this file the single source of truth for the VM's `/etc/caddy/Caddyfile`; the
   Plot Twist repo does **not** carry its own Caddy config.

2. **Node version:** the runbook installs `nodejs npm` from Ubuntu apt for asset builds.
   Plot Twist needs **Node 20+** at runtime on this same box, so install Node 22 from
   NodeSource instead of Ubuntu's apt package, and use it for both purposes:

   ```bash
   curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
   sudo apt install -y nodejs
   ```

3. **After provisioning, report the VM public IP** so the DNS records (including
   `plottwist`) can be added in one sitting.

4. DylanBot LLM decision (§7/§8 of DEPLOY.md) is unchanged: ship with the deterministic
   fallback (Option A), upgrade to hosted Claude Haiku (Option B) later.

## Project 2: Plot Twist (Express + React + MongoDB Atlas)

Your `DEPLOYMENT.md` PaaS table (Render/Railway/Fly) is **superseded**: production is
the shared Azure VM, reverse-proxied by Caddy at **https://plottwist.dylanglover.com**.
Everything else in `DEPLOYMENT.md` (build commands, env vars, single-service model)
still applies. Deployment steps on the VM (after Portfolio's base setup is done):

1. **External services:** create a MongoDB Atlas **M0 free** cluster (region near the
   VM, e.g. AWS us-east-1 for an eastus VM), a database user, and add the **VM's public
   IP** to the Atlas network access list (avoid 0.0.0.0/0). Create/reuse the Unsplash
   developer app for `UNSPLASH_ACCESS_KEY`.

2. **Deploy as a dedicated system user** (mirrors the portfolio's pattern):

   ```bash
   sudo useradd -r -m -d /opt/plottwist -s /bin/bash plottwist
   sudo -u plottwist git clone https://github.com/dylanglover6/<plot-twist-repo>.git /opt/plottwist/src
   cd /opt/plottwist/src
   sudo -u plottwist bash -c 'npm install && npm run build'
   ```

3. **Environment** — `/opt/plottwist/.env`, `chmod 600`, owned by `plottwist`:

   ```
   MONGODB_URI=<Atlas connection string>
   CLIENT_ORIGIN=https://plottwist.dylanglover.com
   UNSPLASH_ACCESS_KEY=<key>
   PORT=3000
   ```

4. **systemd unit** — `/etc/systemd/system/plottwist.service`:

   ```ini
   [Unit]
   Description=Plot Twist (Express + SPA)
   After=network.target

   [Service]
   User=plottwist
   WorkingDirectory=/opt/plottwist/src
   EnvironmentFile=/opt/plottwist/.env
   ExecStart=/usr/bin/npm run start:prod
   Restart=on-failure

   [Install]
   WantedBy=multi-user.target
   ```

   `sudo systemctl enable --now plottwist`

5. **Caddy:** the site block lives in the **Portfolio repo's** `deploy/Caddyfile`
   (already instructed there). Once the `plottwist` A record resolves and Caddy reloads,
   HTTPS is automatic.

6. **Smoke test:** `/`, `/create`, a full invite lifecycle across the `unlockAt` /
   `expiresAt` boundaries, `/api/*` returns JSON, image search works, and og:image
   preview renders when the link is pasted into a chat app.

7. **Redeploy script** (mirror the portfolio's §6): `git pull && npm install &&
   npm run build && sudo systemctl restart plottwist`.

## Project 3: PromptCoach (Azure Static Web Apps)

Your `DEPLOYMENT.md` remains the runbook — this plan only pins down the decisions it
left open:

1. **Hard gate unchanged:** do not share the URL or attach the custom domain until
   rate limiting (input cap, per-IP limits, daily spend ceiling) is merged. Dylan is
   working on this now.
2. **Hosting:** Static Web Apps **Free tier** — it includes 2 custom domains per app,
   free auto-renewing SSL, and managed Functions, which covers everything needed. No
   Standard-tier upgrade required.
3. **Custom domain:** `promptcoach.dylanglover.com` via Portal → Custom domains → Add;
   registrar gets a CNAME pointing at the app's `*.azurestaticapps.net` hostname
   (plus a TXT validation record if prompted).
4. **CORS placeholder (DEPLOYMENT.md §3):** set the allowed origin to
   `https://promptcoach.dylanglover.com` once the domain is attached.
5. **Storage account:** provision when rate limiting merges, per DEPLOYMENT.md §1.2 —
   LRS, used only for the `UsageCounters` table.
6. **Cost controls:** Azure side is free-tier; the real spend is the Anthropic key, so
   the daily spend ceiling + a billing alert in the Anthropic Console are the controls
   that matter (already in your checklist).

---

## Cross-project definition of "live"

- [ ] `https://dylanglover.com` serves the portfolio with valid HTTPS; DylanBot answers (fallback mode)
- [ ] `https://plottwist.dylanglover.com` serves Plot Twist; full invite lifecycle works
- [ ] `https://promptcoach.dylanglover.com` serves PromptCoach; rate limiting demonstrably triggers; GitHub OAuth is real
- [ ] All secrets live only in VM `.env` files / SWA Application Settings — nothing in git
- [ ] Azure budget alert configured; Anthropic Console billing alert configured
- [ ] Portfolio links to both apps (they're the exhibits — make them one click away)
