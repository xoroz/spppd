#!/bin/bash
# Browser build of SPPPD for apps.texngo.it/spppd/ (love.js, compatibility mode). Output: dist/web/.
# Kept out of the upstream repo (listed in .git/info/exclude); the game source is never edited here.
# love.js has no LuaSocket, so the web copy gets a stub `socket` module: ONLINE shows as unavailable,
# everything else (race, time trial, freestyle, editor) runs.
set -euo pipefail
cd "$(dirname "$0")/.."
LOVEJS_VERSION=11.4.1
rm -rf dist/web.new dist/web-src dist/spppd-web.love
mkdir -p dist/web-src
cp -r main.lua conf.lua LICENSE assets src dist/web-src/
sed -i 's/t.version = "11.5"/t.version = "11.4"/' dist/web-src/conf.lua
cat > dist/web-src/main.lua.new <<'LUA'
-- texngo web build: love.js has no LuaSocket; a stub keeps the game loading with online off.
package.preload["socket"] = function()
  local function fail() return nil, "online play is not available in the browser" end
  local udp = setmetatable({}, { __index = function() return fail end })
  return { udp = function() return udp end, gettime = function() return love.timer.getTime() end }
end
-- love.js runs PUC Lua 5.1 (no LuaJIT `bit`); sfxr only needs band/rshift on non-negative integers.
package.preload["bit"] = function()
  local function band(a, b)
    local r, p = 0, 1
    a, b = math.floor(a) % 4294967296, math.floor(b) % 4294967296
    while a > 0 and b > 0 do
      if a % 2 == 1 and b % 2 == 1 then r = r + p end
      a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2
    end
    return r
  end
  return { band = band, rshift = function(a, n) return math.floor((math.floor(a) % 4294967296) / 2 ^ n) end }
end
-- PUC Lua 5.1 cannot yield across pcall; the game loads audio in a coroutine inside a pcall.
-- Inside a coroutine, run the protected function as its own coroutine and pass yields through.
do
  local rawpcall, create, resume, status, yield, running = pcall, coroutine.create, coroutine.resume, coroutine.status, coroutine.yield, coroutine.running
  local function ret(co, ok, ...)
    if not ok then return false, ... end
    if status(co) == "suspended" then return ret(co, resume(co, yield(...))) end
    return true, ...
  end
  pcall = function(f, ...)
    if not running() then return rawpcall(f, ...) end
    local co = create(function(...) return f(...) end)
    return ret(co, resume(co, ...))
  end
end
-- WebGL 1 / love.js mipmaps fail (NPOT sizes, canvases): the web copy uses no mipmaps at all.
do
  local g = love.graphics
  local function pot(n) n = math.floor(n or 0) return n > 0 and n % 1 == 0 and math.log(n) / math.log(2) % 1 < 1e-9 end
  local patched = {}
  local function patch(obj)
    local mt = obj and getmetatable(obj)
    if not mt or patched[mt] then return obj end
    patched[mt] = true
    local methods = mt and type(mt.__index) == "table" and mt.__index
    if methods and methods.setMipmapFilter then
      local set = methods.setMipmapFilter
      methods.setMipmapFilter = function() end
    end
    return obj
  end
  local newImage, newCanvas = g.newImage, g.newCanvas
  g.newImage = function(src, settings)
    if type(settings) == "table" and settings.mipmaps and type(src) == "userdata" and src.getDimensions then
      local w, h = src:getDimensions()
      if true then settings = { linear = settings.linear, dpiscale = settings.dpiscale } end
    end
    return patch(newImage(src, settings))
  end
  g.newCanvas = function(w, h, settings)
    if type(settings) == "table" and settings.mipmaps then
      local copy = {} for k, v in pairs(settings) do copy[k] = v end
      copy.mipmaps = nil
      settings = copy
    end
    return patch(newCanvas(w, h, settings))
  end
end
LUA
cat dist/web-src/main.lua >> dist/web-src/main.lua.new && mv dist/web-src/main.lua.new dist/web-src/main.lua
cat >> dist/web-src/main.lua <<'LUA'
-- texngo web build: love.js does not show errors after start, so print them with a traceback.
do
  local handler = love.errorhandler or love.errhand
  love.errorhandler = function(msg) print("WEBERR handler: " .. tostring(msg) .. "\n" .. debug.traceback()) return handler(msg) end
end
LUA
(cd dist/web-src && zip -q -9 -r ../spppd-web.love .)
npx --yes "love.js@$LOVEJS_VERSION" -c -t "SPPPD" -m 134217728 dist/spppd-web.love dist/web.new
rm -rf dist/web-src
sed -i 's|<link rel="stylesheet" type="text/css" href="theme/love.css">|<link rel="icon" href="data:,">|' dist/web.new/index.html
sed -i 's|</head>|  <style>html, body { margin: 0; height: 100%; overflow: hidden; background: #0b0f14; } h1, footer { display: none; } canvas { display: block; margin: 0 auto; touch-action: none; } #canvas { padding-right: 0; border: 0; }</style>\n  </head>|' dist/web.new/index.html
# swap in only after a complete build, so the live copy never goes missing
rm -rf dist/web.old; [ -d dist/web ] && mv dist/web dist/web.old; mv dist/web.new dist/web; rm -rf dist/web.old
echo "Built dist/web/"
