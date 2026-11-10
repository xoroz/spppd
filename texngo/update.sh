#!/usr/bin/env bash
# Cron: */10 * * * * /home/cbot/projects/spppd/texngo/update.sh >> /home/cbot/logs/spppd-deploy.log 2>&1
# Static app (Apache serves dist/web): pull + rebuild, no service. Logic in ~/scripts/app-update.sh.
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)" BRANCH=master SERVICES="" \
  BUILD="./texngo/build-web.sh" VERSION_CMD="sed -n 's/.*VERSION = \"\\(.*\\)\".*/\\1/p' src/config.lua" \
  exec "$HOME/scripts/app-update.sh"
