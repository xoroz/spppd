#!/usr/bin/env bash
# Cron: */10 * * * * /home/cbot/projects/spppd/update.sh >> /home/cbot/logs/spppd-deploy.log 2>&1
# Logic lives in ~/scripts/app-update.sh (docs: ~/CLAUDE.md "update.sh"), as for game-race.
# The browser build is static files only (dist/web/), so there's no service to restart
# and no health check.
APP_DIR="$(cd "$(dirname "$0")" && pwd)" BRANCH=master SERVICES="" \
  BUILD="./build.sh" VERSION_CMD="git rev-parse --short HEAD" \
  exec "$HOME/scripts/app-update.sh"
