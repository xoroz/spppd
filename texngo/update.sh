#!/usr/bin/env bash
# Cron: */10 * * * * /home/cbot/projects/spppd/texngo/update.sh >> /home/cbot/logs/spppd-deploy.log 2>&1
# Static app + central score/ghost API (pm2 spppd on :3842): pull + rebuild + restart. Logic in ~/scripts/app-update.sh.
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)" BRANCH=master SERVICES="spppd" \
  BUILD="./texngo/build-web.sh" HEALTH_URL="http://127.0.0.1:3842/api/health" \
  VERSION_CMD="sed -n 's/.*VERSION = \"\\(.*\\)\".*/\\1/p' src/config.lua" \
  exec "$HOME/scripts/app-update.sh"
