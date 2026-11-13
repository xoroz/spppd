-- Everything the game remembers between sessions.
local SERVER = "spppd.xyz"
local SERVER_PORT = 8080  -- when the address doesn't name one

local settings = {
  assists = "arcade",
  camera = "chase",
  zoom = "near",
  units = "kmh",
  gearbox = "auto",
  volume = 0.8,
  radioVolume = 0.6,
  music = true,      -- the menu's, see src/music.lua
  musicTake = "a",   -- which of its songs
  quality = "high",
  minimap = true,
  paceNotes = true,
  showFps = false,
  fullscreen = false,
  touch = "auto",
  touchSteer = "stick",  -- or "buttons"
  touchSize = "medium",  -- "small", "medium" or "large"
  touchOpacity = 1,
  touchFeel = "medium",  -- how sharply touch steering answers: "low", "medium" or "high"
  -- The browser build shows GAS and BRAKE buttons on a phone instead.
  autoGas = not (love.system and love.system.getOS() == "Web"),
  vibration = true,
  keys = {},         -- changed keys and pad buttons, see input.setBindings
  padButtons = {},
  tuneHorn = false,  -- cheat codes, see src/cheats.lua
  neon = false,

  -- Last race setup
  mode = "race",
  track = "mirage",
  freestyleTrack = "lot",  -- or any track's name
  car = 1,
  hue = 1,
  laps = 3,
  opponents = 5,
  difficulty = "pro",
  time = "day",
  trialRules = "open",  -- or "clean": see Race.new
  players = 1,       -- 2 splits the screen, with a pad for the second
  car2 = 2,          -- the second driver's car, paint, handling and gearbox
  hue2 = 1,
  assists2 = "arcade",
  gearbox2 = "auto",
  selectedGhost = 0, -- 0 = OFF, 1..5 = top 5 ghost slot for current track

  server = SERVER,
  scoreUrl = "https://apps.texngo.it/spppd/api/records",
}

local records = {}
local FILE = "settings.lua"
local RECORDS = "records.lua"
local CENTRAL_SYNC = "central-sync.lua"
local CENTRAL_STATUS = "central-sync-status.txt"
local TOP_LIMIT = 5

-- Saved files are data: run them with no access to anything.
local function loadTable(path)
  if not love.filesystem.getInfo(path) then return nil end
  local loaded, chunk = pcall(love.filesystem.load, path)
  if not loaded or not chunk then return nil end
  setfenv(chunk, {})
  local ok, data = pcall(chunk)
  if ok and type(data) == "table" then return data end
  return nil
end

local function serialize(value, indent)
  indent = indent or ""
  local kind = type(value)
  if kind == "number" or kind == "boolean" then return tostring(value) end
  if kind == "string" then return string.format("%q", value) end
  if kind == "table" then
    local isFlatNums = #value > 3
    if isFlatNums then
      local count = 0
      for k, v in pairs(value) do
        count = count + 1
        if type(k) ~= "number" or type(v) ~= "number" then isFlatNums = false break end
      end
      if isFlatNums and count == #value then
        local nums = {}
        for i = 1, count do nums[i] = tostring(value[i]) end
        return "{ " .. table.concat(nums, ", ") .. " }"
      end
    end
    local inner = indent .. "  "
    local lines = {}
    local keys = {}
    for k in pairs(value) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
      local v = serialize(value[k], inner)
      if v then
        local key = type(k) == "string" and string.format("[%q]", k) or "[" .. tostring(k) .. "]"
        lines[#lines + 1] = inner .. key .. " = " .. v .. ","
      end
    end
    return "{\n" .. table.concat(lines, "\n") .. "\n" .. indent .. "}"
  end
  return nil
end
settings.serialize = serialize
settings.loadTable = loadTable

-- Clean records keep the key they always had. Open ones are their own table, so a
-- cut lap never beats a clean one.
local function recordKey(trackName, carId, rules)
  return trackName .. "/" .. carId .. (rules == "open" and "/open" or "")
end

local function topKey(trackName)
  return "@top5/" .. tostring(trackName)
end

local function saveRecords()
  pcall(love.filesystem.write, RECORDS, "return " .. serialize(records) .. "\n")
end

local function insertTopEntry(trackName, item)
  if type(trackName) ~= "string" or trackName == "" then return false, nil end
  if type(item) ~= "table" or type(item.time) ~= "number" or item.time <= 0 then return false, nil end
  if type(item.ghost) ~= "table" or #item.ghost == 0 then return false, nil end
  local key = topKey(trackName)
  local list = type(records[key]) == "table" and records[key] or {}
  local car = type(item.car) == "string" and item.car ~= "" and item.car or "hot_hatch"
  local hue = type(item.hue) == "number" and item.hue or 1
  local name = type(item.name) == "string" and item.name ~= "" and item.name or "YOU"
  local rules = item.rules == "open" and "open" or "clean"

  for idx, existing in ipairs(list) do
    if type(existing) == "table"
      and math.abs((existing.time or 0) - item.time) < 1e-4
      and (existing.car or "") == car then
      if type(existing.ghost) ~= "table" or #existing.ghost < #item.ghost then
        existing.ghost = item.ghost
      end
      return false, idx
    end
  end

  local added = {
    time = item.time,
    ghost = item.ghost,
    car = car,
    hue = hue,
    name = name,
    rules = rules,
  }
  list[#list + 1] = added
  table.sort(list, function(a, b) return (a.time or math.huge) < (b.time or math.huge) end)
  while #list > TOP_LIMIT do list[#list] = nil end
  records[key] = list

  for idx, existing in ipairs(list) do
    if existing == added then return true, idx end
  end
  return false, nil
end

local function jsonEscape(str)
  return tostring(str or ""):gsub('[\\"%c]', function(c)
    if c == '\\' then return '\\\\' end
    if c == '"' then return '\\"' end
    return " "
  end)
end

local function encodeSubmitJson(trackName, entry)
  local g = {}
  local ghost = entry.ghost or {}
  for i = 1, #ghost do
    local v = ghost[i]
    if type(v) == "number" then
      g[#g + 1] = tostring(v)
    elseif type(v) == "table" then
      for j = 1, #v do
        if type(v[j]) == "number" then g[#g + 1] = tostring(v[j]) end
      end
    end
  end
  return string.format(
    '{"track":"%s","car":"%s","rules":"%s","time":%.4f,"hue":%d,"name":"%s","ghost":[%s]}',
    jsonEscape(trackName),
    jsonEscape(entry.car or "hot_hatch"),
    jsonEscape(entry.rules or "clean"),
    tonumber(entry.time) or 0,
    tonumber(entry.hue) or 1,
    jsonEscape(entry.name or "YOU"),
    table.concat(g, ",")
  )
end

local function centralFilePath()
  if type(settings.centralFile) == "string" and settings.centralFile ~= "" then
    return settings.centralFile
  end
  local env = os.getenv and os.getenv("SPPPD_CENTRAL_FILE")
  if type(env) == "string" and env ~= "" then return env end
  return nil
end

local function parseLuaTable(body)
  if type(body) ~= "string" or body == "" then return nil end
  local loader = loadstring or load
  local okChunk, chunk = pcall(loader, body)
  if not okChunk or not chunk then return nil end
  if setfenv then setfenv(chunk, {}) end
  local okRun, data = pcall(chunk)
  if okRun and type(data) == "table" then return data end
  return nil
end

local function loadExternalTable(path)
  local okOpen, f = pcall(io.open, path, "rb")
  if not okOpen or not f then return nil end
  local okRead, body = pcall(function()
    local s = f:read("*a")
    f:close()
    return s
  end)
  if not okRead then return nil end
  return parseLuaTable(body)
end

local function centralScoreUrl()
  local env = os.getenv and os.getenv("SPPPD_SCORE_URL")
  if type(env) == "string" and env ~= "" then return env end
  if type(settings.scoreUrl) == "string" and settings.scoreUrl ~= "" then
    return settings.scoreUrl
  end
  return nil
end

local function isRunningTests()
  if settings.enableCentralInTests then return false end
  if type(arg) == "table" then
    for i = 1, 4 do
      if arg[i] == "--test" then return true end
    end
  end
  return false
end

local WORKER_CODE = [[
local reqChan = love.thread.getChannel("spppd_central_req")
local resChan = love.thread.getChannel("spppd_central_res")
local okHttp, http = pcall(require, "socket.http")
local okLtn12, ltn12 = pcall(require, "ltn12")
if okHttp and http then http.TIMEOUT = 4 end

local function withLuaFormat(url)
  if url:find("format=lua", 1, true) then return url end
  return url .. (url:find("?", 1, true) and "&format=lua" or "?format=lua")
end

local function shellQuote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function requestViaSocket(method, url, body)
  if not (okHttp and http and okLtn12 and ltn12) then return nil end
  if not url:match("^http://") then return nil end
  local chunks = {}
  local req = {
    url = url,
    method = method,
    sink = ltn12.sink.table(chunks),
  }
  if body then
    req.source = ltn12.source.string(body)
    req.headers = {
      ["Content-Type"] = "application/json",
      ["Content-Length"] = tostring(#body),
    }
  end
  local ok, _, code = pcall(http.request, req)
  if ok and tonumber(code) == 200 then
    return table.concat(chunks)
  end
  return nil
end

local function requestViaCurl(method, url, body)
  if not (io and io.popen) then return nil end
  local cmd
  if method == "POST" and body then
    cmd = "curl -fsSL --max-time 4 -X POST -H 'Content-Type: application/json' --data-binary "
      .. shellQuote(body) .. " " .. shellQuote(url) .. " 2>/dev/null"
  else
    cmd = "curl -fsSL --max-time 4 " .. shellQuote(url) .. " 2>/dev/null"
  end
  local okOpen, pipe = pcall(io.popen, cmd, "r")
  if not okOpen or not pipe then return nil end
  local okRead, out = pcall(function()
    local s = pipe:read("*a")
    pipe:close()
    return s
  end)
  if okRead and type(out) == "string" and out:match("^%s*return%s+{") then
    return out
  end
  return nil
end

while true do
  local msg = reqChan:demand()
  if type(msg) == "table" then
    if msg.cmd == "quit" then break end
    local url = type(msg.url) == "string" and withLuaFormat(msg.url) or nil
    if url then
      local method = msg.cmd == "submit" and "POST" or "GET"
      local resp = requestViaSocket(method, url, msg.body) or requestViaCurl(method, url, msg.body)
      if type(resp) == "string" and resp ~= "" then
        resChan:push(resp)
      elseif msg.cmd == "fetch" then
        resChan:push("__ERR__")
      end
    end
  end
end
]]

local syncWorker = nil

local function ensureSyncWorker()
  if syncWorker then return true end
  if love._os == "Web" or isRunningTests() then return false end
  if not (love and love.thread and love.thread.newThread and love.thread.getChannel) then
    return false
  end
  local ok, thread = pcall(love.thread.newThread, WORKER_CODE)
  if not ok or not thread then return false end
  local okStart = pcall(function() thread:start() end)
  if not okStart then return false end
  syncWorker = thread
  return true
end

local function enqueueNativeCentral(cmd, payload)
  if love._os == "Web" or isRunningTests() then return false end
  local url = centralScoreUrl()
  if not url then return false end
  if ensureSyncWorker() then
    local ok = pcall(function()
      love.thread.getChannel("spppd_central_req"):push({
        cmd = cmd,
        url = url,
        body = payload,
      })
    end)
    return ok
  end
  return false
end

local function pushCentralFile(trackName, entry)
  local path = centralFilePath()
  if not path then return false end
  local ok = pcall(function()
    local data = loadExternalTable(path) or {}
    local list = type(data[trackName]) == "table" and data[trackName] or {}
    local dup = false
    for _, existing in ipairs(list) do
      if type(existing) == "table"
        and math.abs((existing.time or 0) - entry.time) < 1e-4
        and (existing.car or "") == (entry.car or "") then
        dup = true
        break
      end
    end
    if not dup then
      list[#list + 1] = {
        time = entry.time,
        ghost = entry.ghost,
        car = entry.car,
        hue = entry.hue,
        name = entry.name,
        rules = entry.rules,
      }
      table.sort(list, function(a, b) return (a.time or math.huge) < (b.time or math.huge) end)
      while #list > TOP_LIMIT do list[#list] = nil end
      data[trackName] = list
      local f = assert(io.open(path, "wb"))
      f:write("return " .. serialize(data) .. "\n")
      f:close()
    end
  end)
  return ok
end

local function emitWebBridge(cmd, payload)
  if not (love._os == "Web" or settings.webBridge) then return false end
  if isRunningTests() and not settings.webBridge then return false end
  local ok = pcall(function()
    local dir = love.filesystem.getSaveDirectory and love.filesystem.getSaveDirectory() or ""
    if payload then
      print("SPPPD_API|" .. tostring(dir) .. "|" .. cmd .. "|" .. payload)
    else
      print("SPPPD_API|" .. tostring(dir) .. "|" .. cmd)
    end
  end)
  return ok
end

function settings.mergeCentral(data)
  if type(data) ~= "table" then return false end
  local changed = false
  for trackName, entries in pairs(data) do
    if type(trackName) == "string" and type(entries) == "table" then
      for _, entry in ipairs(entries) do
        if type(entry) == "table" and type(entry.time) == "number" and entry.time > 0 then
          local added = insertTopEntry(trackName, entry)
          if added then changed = true end
          if type(entry.car) == "string" and entry.car ~= "" then
            local k = recordKey(trackName, entry.car, entry.rules)
            local cur = records[k]
            if not cur or cur.time > entry.time then
              records[k] = {
                time = entry.time,
                ghost = entry.ghost,
                car = entry.car,
                hue = entry.hue or 1,
                name = entry.name or "YOU",
              }
              changed = true
            end
          end
        end
      end
    end
  end
  if changed then saveRecords() end
  return changed
end

settings.parseCentralLua = parseLuaTable
settings.syncState = "idle"
settings.syncStartedAt = 0

function settings.pollSync()
  pcall(function()
    if love.filesystem.getInfo(CENTRAL_SYNC) then
      local synced = loadTable(CENTRAL_SYNC)
      love.filesystem.remove(CENTRAL_SYNC)
      if synced then
        settings.mergeCentral(synced)
        settings.syncState = "central"
      end
    end
    if love.filesystem.getInfo(CENTRAL_STATUS) then
      local rawStatus = love.filesystem.read(CENTRAL_STATUS)
      love.filesystem.remove(CENTRAL_STATUS)
      local st = type(rawStatus) == "string" and rawStatus:match("^%s*(%a+)") or nil
      if st == "central" or st == "local" then
        settings.syncState = st
      end
    end
    if love and love.thread and love.thread.getChannel then
      local resChan = love.thread.getChannel("spppd_central_res")
      while resChan do
        local raw = resChan:pop()
        if not raw then break end
        if raw == "__ERR__" then
          if settings.syncState == "syncing" then
            settings.syncState = "local"
          end
        else
          local parsed = parseLuaTable(raw)
          if parsed then
            settings.mergeCentral(parsed)
            settings.syncState = "central"
          elseif settings.syncState == "syncing" then
            settings.syncState = "local"
          end
        end
      end
    end
    local path = centralFilePath()
    if path then
      local central = loadExternalTable(path)
      if central then
        settings.mergeCentral(central)
        settings.syncState = "central"
      end
    end
    if settings.syncState == "syncing" and love and love.timer and love.timer.getTime then
      if love.timer.getTime() - (settings.syncStartedAt or 0) > 2.5 then
        settings.syncState = "local"
      end
    end
  end)
end

function settings.requestSync()
  pcall(function()
    if love and love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(CENTRAL_STATUS) then
      love.filesystem.remove(CENTRAL_STATUS)
    end
  end)
  local startedWeb = emitWebBridge("fetch")
  local startedNative = enqueueNativeCentral("fetch")
  if startedWeb or startedNative then
    settings.syncState = "syncing"
    settings.syncStartedAt = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
  else
    settings.syncState = "local"
  end
  settings.pollSync()
end

function settings.load()
  local data = loadTable(FILE)
  if data then
    for k, v in pairs(data) do
      if type(settings[k]) == type(v) then settings[k] = v end
    end
  end
  -- FULL was replaced by ARCADE as the easiest handling tier.
  if settings.assists == "full" then settings.assists = "arcade" end
  -- MIRAGE replaced LUSAIL. Best laps stay under the old name: it was another road.
  if settings.track == "lusail" then settings.track = "mirage" end
  records = loadTable(RECORDS) or {}
  settings.requestSync()
end

-- The server as a host and a port. Only people running their own need a port.
function settings.serverAddress()
  local host, port = settings.server:match("^(.+):(%d+)$")
  return host or settings.server, tonumber(port) or SERVER_PORT
end

function settings.save()
  local out = {}
  for k, v in pairs(settings) do
    if type(v) ~= "function" then out[k] = v end
  end
  love.filesystem.write(FILE, "return " .. serialize(out) .. "\n")
end

function settings.bestLap(trackName, carId, rules)
  settings.pollSync()
  local r = records[recordKey(trackName, carId, rules)]
  return r and r.time or nil
end

function settings.ghost(trackName, carId, rules)
  settings.pollSync()
  local r = records[recordKey(trackName, carId, rules)]
  return r and r.ghost or nil
end

-- Returns up to the top 5 fastest ghost entries for a track, sorted fastest first.
function settings.topGhosts(trackName)
  if not trackName then return {} end
  settings.pollSync()
  local key = topKey(trackName)
  local list = type(records[key]) == "table" and records[key] or {}
  -- Migrate any legacy single-car records for this track that have a ghost.
  local prefix = tostring(trackName) .. "/"
  local migrated = false
  for k, v in pairs(records) do
    if type(k) == "string" and k:sub(1, #prefix) == prefix and type(v) == "table"
      and type(v.time) == "number" and type(v.ghost) == "table" and #v.ghost > 0 then
      local rest = k:sub(#prefix + 1)
      local carId = rest:gsub("/open$", "")
      local rules = rest:match("/open$") and "open" or "clean"
      if insertTopEntry(trackName, {
        time = v.time, ghost = v.ghost, car = v.car or carId,
        hue = v.hue or 1, name = v.name or "YOU", rules = rules,
      }) then
        migrated = true
      end
    end
  end
  if migrated then
    list = records[key] or {}
    saveRecords()
  end
  local out = {}
  for i = 1, math.min(#list, TOP_LIMIT) do
    if type(list[i]) == "table" and type(list[i].ghost) == "table" and #list[i].ghost > 0 then
      out[#out + 1] = list[i]
    end
  end
  return out
end

function settings.bestTrackLap(trackName)
  local top = settings.topGhosts(trackName)
  if top[1] and top[1].time then return top[1].time end
  local all = settings.trackRecords(trackName)
  return all[1] and all[1].time or nil
end

-- Returns up to TOP_LIMIT fastest records for a track (central + local ghosts
-- and any legacy local car bests), sorted fastest first.
function settings.trackRecords(trackName)
  if not trackName then return {} end
  settings.pollSync()
  local merged = {}
  local seen = {}
  local function push(item)
    if type(item) ~= "table" or type(item.time) ~= "number" or item.time <= 0 then return end
    local rounded = math.floor(item.time * 1000 + 0.5)
    local key = tostring(item.car or "") .. ":" .. rounded .. ":" .. tostring(item.rules or "clean")
    if seen[key] then return end
    seen[key] = true
    merged[#merged + 1] = {
      time = item.time,
      car = item.car,
      hue = item.hue or 1,
      name = item.name or "YOU",
      rules = item.rules == "open" and "open" or "clean",
      ghost = item.ghost,
    }
  end

  local list = records[topKey(trackName)]
  if type(list) == "table" then
    for _, item in ipairs(list) do push(item) end
  end

  local prefix = tostring(trackName) .. "/"
  for k, v in pairs(records) do
    if type(k) == "string" and k:sub(1, #prefix) == prefix and type(v) == "table" and type(v.time) == "number" then
      local rest = k:sub(#prefix + 1)
      local carId = rest:gsub("/open$", "")
      local rules = rest:match("/open$") and "open" or "clean"
      push({
        time = v.time,
        car = v.car or carId,
        hue = v.hue or 1,
        name = v.name or "YOU",
        rules = rules,
        ghost = v.ghost,
      })
    end
  end

  table.sort(merged, function(a, b) return a.time < b.time end)
  while #merged > TOP_LIMIT do merged[#merged] = nil end
  return merged
end

-- Returns true when this lap is a new record for this car/rules, while also
-- keeping the track's top-5 ghost list and syncing to the central leaderboard.
function settings.submitLap(trackName, carId, time, ghost, rules, extra)
  if type(time) ~= "number" or time <= 0 then return false end
  local key = recordKey(trackName, carId, rules)
  local current = records[key]
  local hue = extra and extra.hue or settings.hue or 1
  local name = extra and extra.name or "YOU"
  local isCarRecord = not current or current.time > time
  if isCarRecord then
    records[key] = { time = time, ghost = ghost, car = carId, hue = hue, name = name }
  end
  local entry = {
    time = time,
    ghost = ghost,
    car = carId,
    hue = hue,
    name = name,
    rules = rules == "open" and "open" or "clean",
  }
  local madeTop5 = false
  if type(ghost) == "table" and #ghost > 0 then
    madeTop5 = insertTopEntry(trackName, entry)
  end
  if isCarRecord or madeTop5 then
    saveRecords()
    if type(ghost) == "table" and #ghost > 0 then
      pushCentralFile(trackName, entry)
      pcall(function()
        local payload = encodeSubmitJson(trackName, entry)
        emitWebBridge("submit", payload)
        enqueueNativeCentral("submit", payload)
      end)
    end
  end
  return isCarRecord
end

return settings
