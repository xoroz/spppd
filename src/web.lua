-- The browser build (love.js). The page can't tell the game how big the browser
-- window is, so web/bridge.js writes it into the save folder when asked, and the
-- window follows it here. Everything else reads love.graphics.getDimensions each
-- frame, so nothing more is needed after a resize.
local ui = require("src/ui")
local touch = require("src/touch")

local web = {
  on = love.system ~= nil and love.system.getOS() == "Web",
}

local PREFIX = "SPPPD_WEB|"
local check, size = 0, nil

function web.update(dt)
  if not web.on then return end
  check = check - dt
  if check > 0 then return end
  check = 0.5
  -- love.js raises on a missing file instead of returning nil. The first answer
  -- can land before the save folder exists, so ask again until a size arrives.
  if not love.filesystem.getInfo("viewport.txt") then
    if not size then
      love.filesystem.createDirectory("web")
      print(PREFIX .. love.filesystem.getSaveDirectory() .. "|hello")
      check = 2
    end
    return
  end
  local ok, text = pcall(love.filesystem.read, "viewport.txt")
  if not ok or not text or text == size then return end
  local w, h, phone = text:match("^(%d+) (%d+) ?(%d?)")
  w, h = tonumber(w), tonumber(h)
  if not w or w < 100 or h < 100 then return end
  size = text
  -- A phone's browser plays like the phone build: touch controls and big menus.
  if phone == "1" and not ui.mobile then
    ui.mobile = true
    touch.active = true
  end
  local cw, ch = love.graphics.getDimensions()
  if cw ~= w or ch ~= h then
    love.window.setMode(w, h, { resizable = true, vsync = 1, msaa = 0 })
  end
end

return web
