# SPPPD on apps.texngo.it

Browser copy of SPPPD (upstream game by vanillaiice, GPL-3) at https://apps.texngo.it/spppd/ — public, no login.
These files only add a browser build; the game source is never edited here.

- `build-web.sh` — runs the game's `build.sh` (love.js 11.4.1, `web/bridge.js` for window size, phone touch and
  clicks) into `dist/web.new`, then swaps it in for `dist/web/` when complete. The game itself handles the browser's
  missing sockets, `bit` library, pcall yields and mipmaps, so no shims are added here.
- `leaderboard.py` — central top-5 best lap & ghost car storage service (`127.0.0.1:3842`, pm2 `spppd`,
  SQLite `texngo/data/leaderboard.db`). Serves `GET /api/records` and `POST /api/records` in JSON (for the
  browser bridge) and `?format=lua` (for native desktop LÖVE clients via background `love.thread`).
- `bridge.js` — published as `api-bridge.js`, loaded after the game's `bridge.js` and before `game.js`; intercepts `SPPPD_API`
  console commands from Lua to fetch/submit top-5 ghost records against `/spppd/api/records` and writes
  `central-sync.lua` into Emscripten's IDBFS (`/home/web_user/love/spppd/central-sync.lua`). Both web and
  desktop builds fall back cleanly to local `records.lua` if the central server is unreachable.
- `update.sh` — cron `*/10`, branch `master`, via `~/scripts/app-update.sh`; log `logs/update.log` and `~/logs/spppd-deploy.log`.
- Apache: `ProxyPass /spppd/api/ http://127.0.0.1:3842/api/` + `Alias /spppd` in `/etc/apache2/sites-enabled/001-cbot.conf` (:81).
- Pangolin: target `/spppd` + allow rules (priority 9, 10) in `~/apps/newt/blueprint.yml`; the `/*` pass rule must stay last.
