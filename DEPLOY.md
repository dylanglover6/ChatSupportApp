# Deploying to dylanglover.com (Azure, cheap-and-simple)

One small Azure VM running Postgres + this app's Elixir release under systemd, with
Caddy in front for automatic HTTPS. No Ollama in production — `AI.Client` already
degrades to its deterministic fallback when Ollama is unreachable, so DylanBot keeps
working, just without a live local model. That's the whole cost/complexity tradeoff:
one box, no managed database, no container registry, no CI.

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

Cheapest option that survives compiling the release once and then running it
indefinitely: **B1s (1 vCPU / 1GB RAM) + a 2GB swap file**, Ubuntu 24.04 LTS. At current
Azure pricing that's roughly $7–9/month — a year of it fits comfortably inside the
Azure for Students $100 credit, especially since student subscriptions also include some
services free for 12 months. If you'd rather not manage swap, size up to **B2s (2 vCPU /
4GB)** instead (~$30–35/month) for more headroom — still fine on the credit for several
months, just not the whole year unmonitored.

```bash
az login
az group create --name dylanglover-rg --location eastus

az vm create \
  --resource-group dylanglover-rg \
  --name dylanglover-vm \
  --image Ubuntu2404 \
  --size Standard_B1s \
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

# swap, if you went with B1s
sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Erlang/Elixir — Erlang Solutions repo has current versions for Ubuntu 24.04
curl -1sLf https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb -o erlang-solutions.deb
sudo dpkg -i erlang-solutions.deb
sudo apt update && sudo apt install -y esl-erlang elixir
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
sudo -u support_bot git clone https://github.com/dylanglover6/ChatSupportApp.git /opt/support_bot/src
cd /opt/support_bot/src

sudo -u support_bot bash -c '
  mix deps.get --only prod
  (cd assets && npm install)
  MIX_ENV=prod mix assets.deploy
  MIX_ENV=prod mix release --overwrite
'

sudo ln -sfn /opt/support_bot/src/_build/prod/rel/support_bot /opt/support_bot/current
```

Copy `deploy/env.example` to `/opt/support_bot/.env`, fill in real values (generate
`SECRET_KEY_BASE` with `mix phx.gen.secret` on the VM), lock it down:

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
  bin/support_bot eval "SupportBot.Release.seed()"
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

## What you're intentionally not getting

No CI/CD (deploys are manual, above), no managed Postgres (self-hosted on the same box,
so back it up yourself — `pg_dump` on a cron is enough for a portfolio site), no Ollama
in production (DylanBot runs in fallback mode live), no zero-downtime deploys (`systemctl
restart` drops connections briefly), no autoscaling. All reasonable to skip for a
low-traffic personal site; revisit if that stops being true.
