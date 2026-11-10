#!/bin/bash
# Browser build of SPPPD for apps.texngo.it/spppd/. Output: dist/web/.
# The game's own build.sh does the work (love.js, web/bridge.js for window size, touch
# and clicks); this adds texngo/bridge.js as api-bridge.js for the central leaderboard,
# builds into dist/web.new and swaps it in once complete, so the live copy never goes
# missing mid-build.
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf dist/web.new
WEB_OUT=dist/web.new ./build.sh
# After the game's bridge (which takes Module.print first) and before game.js: it wraps
# Module.print to answer SPPPD_API lines and passes everything else on.
cp texngo/bridge.js dist/web.new/api-bridge.js
sed -i 's|<script type="text/javascript" src="game.js"></script>|<script type="text/javascript" src="api-bridge.js"></script>\n    &|' dist/web.new/index.html
grep -q 'src="api-bridge.js"' dist/web.new/index.html || { echo "failed to inject api-bridge.js into index.html"; exit 1; }
rm -rf dist/web.old; [ -d dist/web ] && mv dist/web dist/web.old; mv dist/web.new dist/web; rm -rf dist/web.old
echo "Built dist/web/"
