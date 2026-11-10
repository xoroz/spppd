# SPPPD on apps.texngo.it

Browser copy of SPPPD (upstream game by vanillaiice, GPL-3) at https://apps.texngo.it/spppd/ — public, no login.
These files only add a browser build; the game source is never edited here.

- `build-web.sh` — love.js 11.4.1 build into `dist/web/` (built in `dist/web.new`, swapped in when complete).
  Web-only shims prepended to the packaged `main.lua`: stub `socket` (ONLINE does not work in a browser),
  pure-Lua `bit`, coroutine-safe `pcall` (PUC Lua 5.1 can't yield across pcall; audio loads in a coroutine),
  no mipmaps (WebGL 1), and an error handler that prints tracebacks to the browser console.
- `update.sh` — cron `*/10`, branch `master`, via `~/scripts/app-update.sh`; log `logs/update.log` and `~/logs/spppd-deploy.log`.
- Apache: `Alias /spppd` in `/etc/apache2/sites-enabled/001-cbot.conf` (:81).
- Pangolin: target `/spppd` + allow rules (priority 9, 10) in `~/apps/newt/blueprint.yml`; the `/*` pass rule must stay last.
