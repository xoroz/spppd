#!/bin/bash
# Builds the browser version into dist/web/ with love.js, and the .love it's made from.
# Upload the contents of dist/web/ to any static web server (no special headers needed).
#   ./build.sh            dist/spppd-<version>.love, then dist/web/
#   ./build.sh --no-web   the .love only
set -euo pipefail
cd "$(dirname "$0")"

LOVEJS_VERSION=11.4.1   # newest love.js; runs LÖVE 11.4, which this game is compatible with
VERSION=$(sed -n 's/.*VERSION = "\(.*\)".*/\1/p' src/config.lua)

rm -rf dist/web dist/web-src
mkdir -p dist
rm -f "dist/spppd-$VERSION.love"
zip -q -9 -r "dist/spppd-$VERSION.love" main.lua conf.lua LICENSE assets src
echo "Built dist/spppd-$VERSION.love"

if [ "${1:-}" = "--no-web" ]; then exit 0; fi
if ! command -v npx >/dev/null; then
  echo "npx not found: skipping web build (install Node.js to build dist/web/)"
  exit 0
fi

# love.js 11.4 shows a version warning for a game asking for 11.5, so the web copy asks for 11.4.
mkdir -p dist/web-src
cp -r main.lua conf.lua LICENSE assets src dist/web-src/
sed -i 's/t.version = "11.5"/t.version = "11.4"/' dist/web-src/conf.lua
grep -q 't.version = "11.4"' dist/web-src/conf.lua || { echo "failed to patch conf.lua to 11.4"; exit 1; }
(cd dist/web-src && zip -q -9 -r ../spppd-web.love .)
# -c = compatibility mode: no threads, so the server needs no COOP/COEP headers.
# -m: the heap. Generated textures, car sprites and every sound live in it.
npx --yes "love.js@$LOVEJS_VERSION" -c -t "SPPPD" -m 536870912 dist/spppd-web.love dist/web
rm -rf dist/web-src dist/spppd-web.love

# The page bridge (window size) must load before game.js so it can hook Module.print.
cp web/bridge.js dist/web/
sed -i 's|<script type="text/javascript" src="game.js"></script>|<script type="text/javascript" src="bridge.js"></script>\n    &|' dist/web/index.html
grep -q 'src="bridge.js"' dist/web/index.html || { echo "failed to inject bridge.js into index.html"; exit 1; }
# Full-window page: no header or footer, dark loading screen, inline favicon, no scrolling or zooming by touch.
sed -i 's|<link rel="stylesheet" type="text/css" href="theme/love.css">|<link rel="icon" href="data:,">|' dist/web/index.html
sed -i 's|rgb(142, 195, 227)|#101418|g; s|rgb( 11, 86, 117 )|#f2c230|g' dist/web/index.html
sed -i 's|</head>|  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">\n  <style>html, body { margin: 0; height: 100%; overflow: hidden; background: #101418; } h1, footer { display: none; } canvas { display: block; margin: 0 auto; touch-action: none; } #canvas { padding-right: 0; border: 0; visibility: hidden; }</style>\n  </head>|' dist/web/index.html
grep -q 'touch-action: none' dist/web/index.html || { echo "failed to inject page style into index.html"; exit 1; }
echo "Built dist/web/ (serve over HTTP, e.g. python3 -m http.server -d dist/web 8020; opening index.html from disk does not work)"
