# SPPPD on apps.texngo.it

Browser copy of SPPPD (upstream game by vanillaiice, GPL-3) at https://apps.texngo.it/spppd/ — public, no login.
These files only add a browser build; the game source is never edited here.

- `build-web.sh` — love.js 11.4.1 build into `dist/web/` (built in `dist/web.new`, swapped in when complete).
  Web-only shims prepended to the packaged `main.lua`: stub `socket` (ONLINE does not work in a browser),
  pure-Lua `bit`, coroutine-safe `pcall` (PUC Lua 5.1 can't yield across pcall; audio loads in a coroutine),
  no mipmaps (WebGL 1), and an error handler that prints tracebacks to the browser console.
- `leaderboard.py` — central top-5 best lap & ghost car storage service (`127.0.0.1:3842`, pm2 `spppd`,
  SQLite `texngo/data/leaderboard.db`). Serves `GET /api/records` and `POST /api/records` in JSON (for the
  browser bridge) and `?format=lua` (for native desktop LÖVE clients via background `love.thread`).
- `bridge.js` — browser bridge loaded before `game.js` in `dist/web/index.html`; intercepts `SPPPD_API`
  console commands from Lua to fetch/submit top-5 ghost records against `/spppd/api/records` and writes
  `central-sync.lua` into Emscripten's IDBFS (`/home/web_user/love/spppd/central-sync.lua`). Both web and
  desktop builds fall back cleanly to local `records.lua` if the central server is unreachable.
- `update.sh` — cron `*/10`, branch `master`, via `~/scripts/app-update.sh`; log `logs/update.log` and `~/logs/spppd-deploy.log`.
- Apache: `ProxyPass /spppd/api/ http://127.0.0.1:3842/api/` + `Alias /spppd` in `/etc/apache2/sites-enabled/001-cbot.conf` (:81).
- Pangolin: target `/spppd` + allow rules (priority 9, 10) in `~/apps/newt/blueprint.yml`; the `/*` pass rule must stay last.
