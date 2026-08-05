#!/usr/bin/env bash
# Redeploy the portfolio (Phoenix) app after a git change.
# Install on the VM as /usr/local/bin/redeploy-portfolio (chmod +x).
# Usage:  sudo redeploy-portfolio
set -euo pipefail

APP_USER=support_bot
SRC=/opt/support_bot/src
CURRENT=/opt/support_bot/current
ENV_FILE=/opt/support_bot/.env
SERVICE=support_bot

echo "==> Pulling latest + building release (as $APP_USER)"
sudo -u "$APP_USER" bash -c "
  set -euo pipefail
  cd '$SRC'
  git pull
  mix deps.get --only prod
  (cd assets && npm install)
  MIX_ENV=prod mix assets.deploy
  MIX_ENV=prod mix release --overwrite
"

echo "==> Running migrations"
sudo -u "$APP_USER" bash -c "
  set -euo pipefail
  cd '$CURRENT'
  set -a; source '$ENV_FILE'; set +a
  bin/support_bot eval 'SupportBot.Release.migrate()'
"

echo "==> Restarting $SERVICE"
sudo systemctl restart "$SERVICE"

sleep 2
echo "==> Done. Recent status:"
sudo systemctl status "$SERVICE" --no-pager -n 10 || true
