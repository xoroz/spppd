-- Country metadata, flag palettes, and crisp geometric flag drawing for real circuits.
local flags = {}

flags.COUNTRIES = {
  IT = {
    name = "ITALY",
    palette = {
      { 0.00, 0.57, 0.27 },
      { 0.98, 0.98, 0.96 },
      { 0.84, 0.14, 0.18 },
    },
  },
  ES = {
    name = "SPAIN",
    palette = {
      { 0.80, 0.10, 0.14 },
      { 0.98, 0.78, 0.08 },
      { 0.80, 0.10, 0.14 },
    },
  },
  AT = {
    name = "AUSTRIA",
    palette = {
      { 0.86, 0.14, 0.18 },
      { 0.98, 0.98, 0.96 },
      { 0.86, 0.14, 0.18 },
    },
  },
  GB = {
    name = "UK",
    palette = {
      { 0.06, 0.22, 0.58 },
      { 0.98, 0.98, 0.96 },
      { 0.84, 0.12, 0.18 },
    },
  },
  BR = {
    name = "BRAZIL",
    palette = {
      { 0.00, 0.56, 0.24 },
      { 0.98, 0.82, 0.08 },
      { 0.06, 0.22, 0.58 },
    },
  },
  US = {
    name = "USA",
    palette = {
      { 0.80, 0.12, 0.18 },
      { 0.98, 0.98, 0.96 },
      { 0.08, 0.22, 0.56 },
    },
  },
  MC = {
    name = "MONACO",
    palette = {
      { 0.84, 0.12, 0.16 },
      { 0.98, 0.98, 0.96 },
      { 0.84, 0.12, 0.16 },
    },
  },
}

function flags.info(code)
  return code and flags.COUNTRIES[code] or nil
end

function flags.countryName(code)
  local info = flags.info(code)
  return info and info.name or nil
end

function flags.palette(code)
  local info = flags.info(code)
  return info and info.palette or nil
end

local function rect(c, x, y, w, h)
  love.graphics.setColor(c[1], c[2], c[3], 1)
  love.graphics.rectangle("fill", x, y, w, h)
end

-- Draws a crisp flat flag inside (x, y, w, h) with a thin dark frame.
function flags.draw(code, x, y, w, h)
  if not (love and love.graphics and code) then return false end
  local info = flags.info(code)
  if not info then return false end
  local p = info.palette
  local r, g, b = { 0.84, 0.12, 0.18 }, { 0.00, 0.56, 0.24 }, { 0.06, 0.22, 0.58 }
  local wt, yl = { 0.98, 0.98, 0.96 }, { 0.98, 0.80, 0.08 }

  if code == "IT" then
    local bw = w / 3
    rect(p[1], x, y, bw, h)
    rect(p[2], x + bw, y, bw, h)
    rect(p[3], x + bw * 2, y, w - bw * 2, h)
  elseif code == "ES" then
    local top = h * 0.25
    rect(p[1], x, y, w, top)
    rect(p[2], x, y + top, w, h - top * 2)
    rect(p[3], x, y + h - top, w, top)
    rect(p[1], x + w * 0.22, y + h * 0.34, w * 0.14, h * 0.32)
  elseif code == "AT" then
    local bh = h / 3
    rect(p[1], x, y, w, bh)
    rect(p[2], x, y + bh, w, bh)
    rect(p[3], x, y + bh * 2, w, h - bh * 2)
  elseif code == "MC" then
    local bh = h / 2
    rect(p[1], x, y, w, bh)
    rect(p[2], x, y + bh, w, h - bh)
  elseif code == "BR" then
    rect(g, x, y, w, h)
    love.graphics.setColor(yl[1], yl[2], yl[3], 1)
    love.graphics.polygon("fill",
      x + w * 0.5, y + h * 0.12,
      x + w * 0.88, y + h * 0.5,
      x + w * 0.5, y + h * 0.88,
      x + w * 0.12, y + h * 0.5)
    love.graphics.setColor(b[1], b[2], b[3], 1)
    love.graphics.circle("fill", x + w * 0.5, y + h * 0.5, math.min(w, h) * 0.22)
    rect(wt, x + w * 0.35, y + h * 0.47, w * 0.30, math.max(1, h * 0.08))
  elseif code == "US" then
    local stripes = 7
    local sh = h / stripes
    for i = 0, stripes - 1 do
      rect(i % 2 == 0 and r or wt, x, y + i * sh, w, sh + 0.5)
    end
    local cw, ch = w * 0.46, sh * 4
    rect(b, x, y, cw, ch)
    love.graphics.setColor(wt[1], wt[2], wt[3], 1)
    local dot = math.max(1, math.min(w, h) * 0.08)
    for row = 1, 2 do
      for col = 1, 3 do
        love.graphics.rectangle("fill", x + cw * (col * 0.25) - dot * 0.5, y + ch * (row * 0.33) - dot * 0.5, dot, dot)
      end
    end
  elseif code == "GB" then
    rect(b, x, y, w, h)
    love.graphics.setColor(wt[1], wt[2], wt[3], 1)
    love.graphics.setLineWidth(math.max(1.5, math.min(w, h) * 0.22))
    love.graphics.line(x, y, x + w, y + h)
    love.graphics.line(x + w, y, x, y + h)
    love.graphics.setColor(r[1], r[2], r[3], 1)
    love.graphics.setLineWidth(math.max(1, math.min(w, h) * 0.11))
    love.graphics.line(x, y, x + w, y + h)
    love.graphics.line(x + w, y, x, y + h)
    local cw, ch = math.max(2, w * 0.26), math.max(2, h * 0.30)
    rect(wt, x + (w - cw) / 2, y, cw, h)
    rect(wt, x, y + (h - ch) / 2, w, ch)
    local rw, rh = math.max(1, w * 0.14), math.max(1, h * 0.18)
    rect(r, x + (w - rw) / 2, y, rw, h)
    rect(r, x, y + (h - rh) / 2, w, rh)
  end

  love.graphics.setColor(0.10, 0.11, 0.16, 0.9)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x, y, w, h)
  return true
end

return flags
