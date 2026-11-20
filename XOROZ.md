# XOROZ Edition — Merge & Customization Policy

This fork (`github.com/xoroz/spppd`) extends upstream SPPPD (`vanillaiice/spppd`).
**When merging updates from `upstream/master`, ALWAYS preserve the XOROZ settings, cars, tracks, and features below unless explicitly asked not to.**

## Preserved Customizations

1. **6-Car Garage & Categories** (`src/entities/garage.lua`, `src/entities/vehicles/`):
   - **ROAD**: `hot_hatch` (FWD), `rocket` (RWD), `paname` (AWD — Porsche Panamera GTS 976)
   - **RACE**: `formula_kid` (Tatuus T-318 F3), `pursa_gt3` (AWD Porsche 911 GT3 RS 992), `formula_1_1988` (McLaren MP4/4)
   - Categories do not mix by default (`settings.mixCategories = false` in `src/settings.lua` and `Race:spawnOpponents` in `src/sim/race.lua`).
2. **Car Cards** (`src/menu.lua`, `src/sim/car_stats.lua`):
   - Category badge (`ROAD` / `RACE`), Max Speed + drivetrain, and 1–5 star ratings only.
3. **9 Real Circuits Only** (`src/tracks/catalog.lua`, `src/tracks/manifest.lua`):
   - `mugello`, `imola`, `barcelona`, `spielberg`, `monza`, `brands_hatch`, `interlagos`, `austin`, `monaco` (with country flags & palettes in `src/flags.lua`).
4. **Track Rubbered-In Racing Line & 3-2-1 Brake Markers** (`src/sim/track.lua`, `src/sim/dynamics.lua`, `src/render/track_renderer.lua`):
   - Darker rubbered-in groove along the racing line (`rubber` surface, `grip = 1.28`).
   - High-contrast `3` (300 m), `2` (200 m), `1` (100 m) brake markers placed inside the track map before braking zones.
5. **Default Settings** (`src/settings.lua`, `src/race_manager.lua`):
   - `camera = "top"` (new high, fixed top-down view), `zoom = "far"`, `track = "mugello"`, `selectedGhost = 1` (ghost ON by default), `mixCategories = false`, `playerName = "PLAYER"`.
6. **Player Name, Central Leaderboard, Changelog & Credit** (`src/menu.lua`, `src/settings.lua`, `texngo/`, `CHANGELOG.md`):
   - Editable `PLAYER NAME` saved to local & central records/ghosts.
   - `CHANGELOG` screen in main menu (`CHANGELOG.md` bundled in `build.sh` and `Makefile`).
   - Credit: `Version edited by XOROZ` in Credits and pit board footer.

## Upstream Merge Checklist
When running `git merge upstream/master`:
- Keep our versions (`--ours`) for `src/entities/garage.lua`, `src/entities/vehicles/`, `src/tracks/catalog.lua`, and `src/tracks/manifest.lua`.
- Re-verify `src/settings.lua` defaults (`camera = "top"`, `selectedGhost = 1`, `track = "mugello"`, `mixCategories = false`, `playerName`).
- Re-verify `ROAD_SHADER` rubber groove + `brakeMarkers` in `src/sim/track.lua` and `src/render/track_renderer.lua`.
- Run `./bin/test-parallel` and `./texngo/build-web.sh` before pushing.
