#!/bin/bash
# Browser build of SPPPD for apps.texngo.it/spppd/. Output: dist/web/.
# The game's own build.sh does the work (love.js, web/bridge.js for window size, touch
# and clicks); this only builds into dist/web.new and swaps it in once complete, so the
# live copy never goes missing mid-build.
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf dist/web.new
WEB_OUT=dist/web.new ./build.sh
rm -rf dist/web.old; [ -d dist/web ] && mv dist/web dist/web.old; mv dist/web.new dist/web; rm -rf dist/web.old
echo "Built dist/web/"
