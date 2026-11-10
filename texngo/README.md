# SPPPD on apps.texngo.it

Browser copy of SPPPD (upstream game by vanillaiice, GPL-3) at https://apps.texngo.it/spppd/ — public, no login.
These files only add a browser build; the game source is never edited here.

- `build-web.sh` — runs the game's `build.sh` (love.js 11.4.1, `web/bridge.js` for window size, phone touch and
  clicks) into `dist/web.new`, then swaps it in for `dist/web/` when complete. The game itself handles the browser's
  missing sockets, `bit` library, pcall yields and mipmaps, so no shims are added here.
- `update.sh` — cron `*/10`, branch `master`, via `~/scripts/app-update.sh`; log `logs/update.log` and `~/logs/spppd-deploy.log`.
- Apache: `Alias /spppd` in `/etc/apache2/sites-enabled/001-cbot.conf` (:81).
- Pangolin: target `/spppd` + allow rules (priority 9, 10) in `~/apps/newt/blueprint.yml`; the `/*` pass rule must stay last.
